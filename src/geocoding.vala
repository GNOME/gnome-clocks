/*
 * Copyright (C) 2013  Evgeny Bobkin <evgen.ibqn@gmail.com>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

namespace Clocks {
namespace Geo {

[DBus (name = "org.freedesktop.GeoClue2.Manager")]
private interface Manager : Object {
    public abstract async void get_client (out string client_path) throws IOError;
}

[DBus (name = "org.freedesktop.GeoClue2.Client")]
private interface Client : Object {
    public abstract string location { owned get; }
    public abstract uint distance_threshold { get; set; }

    public signal void location_updated (string old_path, string new_path);

    public abstract async void start () throws IOError;

    // This function belongs to the Geoclue interface, however it is not used here
    // public abstract async void stop () throws IOError;
}

[DBus (name = "org.freedesktop.GeoClue2.Location")]
public interface Location : Object {
    public abstract double latitude { get; }
    public abstract double longitude { get; }
    public abstract double accuracy { get; }
    public abstract string description { owned get; }
}

public class Info : Object {
    public Geo.Location? geo_location { get; private set; default = null; }

    private GWeather.Location? found_location;
    private string? country_code;
    private Geo.Manager manager;
    private Geo.Client client;
    private double minimal_distance;

    public signal void location_changed (GWeather.Location location);

    public Info () {
        country_code = null;
        found_location = null;
        minimal_distance = 1000.0d;
    }

    public async void seek () {
        string? client_path = null;

        try {
            manager = yield Bus.get_proxy (GLib.BusType.SYSTEM,
                                           "org.freedesktop.GeoClue2",
                                           "/org/freedesktop/GeoClue2/Manager");
        } catch (IOError e) {
            warning ("Failed to connect to GeoClue2 Manager service: %s", e.message);
            return;
        }

        try {
            yield manager.get_client (out client_path);
        } catch (IOError e) {
            warning ("Failed to connect to GeoClue2 Manager service: %s", e.message);
            return;
        }

        if (client_path == null) {
            warning ("The client path is not set");
            return;
        }

        try {
            client = yield Bus.get_proxy (GLib.BusType.SYSTEM,
                                          "org.freedesktop.GeoClue2",
                                          client_path);
        } catch (IOError e) {
            warning ("Failed to connect to GeoClue2 Client service: %s", e.message);
            return;
        }

        client.location_updated.connect ((old_path, new_path) => {
            on_location_updated.begin (old_path, new_path, (obj, res) => {
                on_location_updated.end (res);
            });
        });

        try {
            yield client.start ();
        } catch (IOError e) {
            warning ("Failed to start client: %s", e.message);
            return;
        }
    }

    public async void on_location_updated (string old_path, string new_path) {
        try {
            geo_location = yield Bus.get_proxy (GLib.BusType.SYSTEM,
                                                "org.freedesktop.GeoClue2",
                                                new_path);
        } catch (IOError e) {
            warning ("Failed to connect to GeoClue2 Location service: %s", e.message);
            return;
        }

        yield seek_country_code ();

        yield search_locations (GWeather.Location.get_world ());

        if (found_location != null) {
            location_changed (found_location);
        }
    }

    private async void seek_country_code () {
        Geocode.Location location = new Geocode.Location (geo_location.latitude, geo_location.longitude);
        Geocode.Reverse reverse = new Geocode.Reverse.for_location (location);

        try {
            Geocode.Place place = yield reverse.resolve_async ();

            country_code = place.get_country_code ();

            // Reverse geocoding returns country code which is not uppercased
            country_code = country_code.up ();
        } catch (Error e) {
            warning ("Failed to obtain country code: %s", e.message);
        }
    }

    private double deg_to_rad (double deg) {
        return Math.PI / 180.0d * deg;
    }

    private double get_distance (double latitude1, double longitude1, double latitude2, double longitude2) {
        const double earth_radius = 6372.795;

        double lat1 = deg_to_rad (latitude1);
        double lat2 = deg_to_rad (latitude2);
        double lon1 = deg_to_rad (longitude1);
        double lon2 = deg_to_rad (longitude2);

        return Math.acos (Math.cos (lat1) * Math.cos (lat2) * Math.cos (lon1 - lon2) + Math.sin (lat1) * Math.sin (lat2)) * earth_radius;
    }

    private async void search_locations (GWeather.Location location) {
        if (this.country_code != null) {
            string? loc_country_code = location.get_country ();
            if (loc_country_code != null) {
                if (loc_country_code != this.country_code) {
                    return;
                }
            }
        }

        GWeather.Location? [] locations = location.get_children ();
        if (locations != null) {
            for (int i = 0; i < locations.length; i++) {
                if (locations[i].get_level () == GWeather.LocationLevel.CITY) {
                    if (locations[i].has_coords ()) {
                        double latitude, longitude, distance;

                        locations[i].get_coords (out latitude, out longitude);
                        distance = get_distance (geo_location.latitude, geo_location.longitude, latitude, longitude);

                        if (distance < minimal_distance) {
                            found_location = locations[i];
                            minimal_distance = distance;
                        }
                    }
                }

                yield search_locations (locations[i]);
            }
        }
    }

    public bool is_location_similar (GWeather.Location location) {
        if (this.found_location != null) {
            string? country_code = location.get_country ();
            string? found_country_code = found_location.get_country ();
            if (country_code != null && country_code == found_country_code) {
                GWeather.Timezone? timezone = location.get_timezone();
                GWeather.Timezone? found_timezone = found_location.get_timezone();

                if (timezone != null && found_timezone != null) {
                    string? tzid = timezone.get_tzid ();
                    string? found_tzid = found_timezone.get_tzid ();
                    if (tzid == found_tzid) {
                        return true;
                    }
                }
            }
        }

        return false;
    }
}

} // Geo
} // Clocks
