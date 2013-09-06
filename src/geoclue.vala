namespace Clocks {

namespace GClue {

[DBus (name = "org.freedesktop.GeoClue2.Manager")]
private interface Manager : Object {
    public abstract async void get_client (out string client_path) throws IOError;
}

[DBus (name = "org.freedesktop.GeoClue2.Client")]
private interface Client : Object {
    public abstract string location { owned get; }
    public abstract uint distance_threshold { get; set; }
    public abstract async void start () throws IOError;
    public abstract async void stop () throws IOError;
    public signal void location_updated (string old_path, string new_path);
}

[DBus (name = "org.freedesktop.GeoClue2.Location")]
public interface Location : Object {
    public abstract double latitude { get; }
    public abstract double longitude { get; }
    public abstract double accuracy { get; }
    public abstract string description { owned get; }
}

public class GeoInfo : Object {
    public signal void location_changed (GWeather.Location location);
    public GClue.Location? geo_location { get; private set; default = null; }
    private GWeather.Location? found_location;
    private string? country_code;

    public GeoInfo () {
        country_code = null;
        found_location = null;
    }

    public async void seek () {
        GClue.Manager manager;
        GClue.Client client;

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

        client.location_updated.connect (on_location_updated);

        try {
            yield client.start ();
        } catch (IOError e) {
            warning ("Failed to start client: %s", e.message);
            return;
        }
    }

    public async void on_location_updated (string old_path, string new_path) {
        GClue.Location location;
        try {
            location = yield Bus.get_proxy (GLib.BusType.SYSTEM,
                                            "org.freedesktop.GeoClue2",
                                            new_path);
        } catch (IOError e) {
            warning ("Failed to connect to GeoClue2 Location service: %s", e.message);
            return;
        }

        this.geo_location = location;

        yield seek_country_code ();

        this.found_location = search_locations ();

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
        } catch (IOError e) {
            warning ("Failed to obtain country code: %s", e.message);
        }
    }

    private double deg_to_rad (double deg) {
        return Math.PI / 180.0d * deg;
    }

    private double get_distance (double latitude1, double longitude1, double latitude2, double longitude2) {
        const double radius = 6372.795;

        double lat1 = deg_to_rad (latitude1);
        double lat2 = deg_to_rad (latitude2);
        double lon1 = deg_to_rad (longitude1);
        double lon2 = deg_to_rad (longitude2);

        return Math.acos (Math.cos (lat1) * Math.cos (lat2) * Math.cos (lon1 - lon2) + Math.sin (lat1) * Math.sin (lat2)) * radius;
    }

    private void search_locations_helper (GWeather.Location location, ref double minimal_distance,  ref GWeather.Location? found_location) {
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

                search_locations_helper (locations[i], ref minimal_distance, ref found_location);
            }
        }
    }

    private GWeather.Location? search_locations () {
        GWeather.Location locations = GWeather.Location.get_world ();
        GWeather.Location? found_location = null;
        double minimal_distance = 1000.0d;

        search_locations_helper (locations, ref minimal_distance, ref found_location);

        return found_location;
    }

    public bool is_location_similar (GWeather.Location location) {
        if (this.found_location != null) {
            string? city_name = location.get_city_name ();
            string? found_city_name = found_location.get_city_name ();
            if (city_name == found_city_name) {
                return true;
            }
        }

        return false;
    }
}

} // GClue

} // Clocks
