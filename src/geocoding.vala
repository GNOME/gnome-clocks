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

public class Info : Object {
    public GClue.Location? geo_location { get; private set; default = null; }

    private const string DESKTOP_ID = "org.gnome.clocks";

    private GWeather.Location? found_location;
    private string? country_code;
    private GClue.Simple simple;
    private double minimal_distance;

    public signal void location_changed (GWeather.Location location);

    public Info () {
        country_code = null;
        found_location = null;
        minimal_distance = 1000.0d;
    }

    public async void seek () {
        try {
            simple = yield new GClue.Simple (DESKTOP_ID, GClue.AccuracyLevel.CITY, null);
        } catch (Error e) {
            warning ("Failed to connect to GeoClue2 service: %s", e.message);
            return;
        }

        simple.notify["location"].connect (() => {
            on_location_updated.begin ();
        });

        on_location_updated.begin ();
    }

    public async void on_location_updated () {
        geo_location = simple.get_location ();

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
        } catch (Error e) {
            warning ("Failed to obtain country code: %s", e.message);
        }
    }

    private double deg_to_rad (double deg) {
        return Math.PI / 180.0d * deg;
    }

    private double get_distance (double latitude1, double longitude1, double latitude2, double longitude2) {
        const double earth_radius = 6372.795d;

        double lat1 = deg_to_rad (latitude1);
        double lat2 = deg_to_rad (latitude2);
        double lon1 = deg_to_rad (longitude1);
        double lon2 = deg_to_rad (longitude2);

        return Math.acos (Math.cos (lat1) * Math.cos (lat2) * Math.cos (lon1 - lon2) +
                          Math.sin (lat1) * Math.sin (lat2)) * earth_radius;
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
