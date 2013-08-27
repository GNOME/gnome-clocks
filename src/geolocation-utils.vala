namespace GeoInfo {
namespace Utils {
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

private void search_locations_helper (GeoInfo.LocationInfo geo_location, GWeather.Location location, ref double minimal_distance,  ref GWeather.Location? found_location) {
    if (geo_location.country_code != null) {
        string? country_code = location.get_country ();
        if (country_code != null) {
            if (country_code != geo_location.country_code) {
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

            search_locations_helper (geo_location, locations[i], ref minimal_distance, ref found_location);
        }
    }
}

public GWeather.Location? search_locations (GeoInfo.LocationInfo geo_location) {
    GWeather.Location locations = new GWeather.Location.world (true);
    GWeather.Location? found_location = null;
    double minimal_distance = 1000.0d;

    search_locations_helper (geo_location, locations, ref minimal_distance, ref found_location);

    return found_location;
}

}// Utils
}// GeoIp
