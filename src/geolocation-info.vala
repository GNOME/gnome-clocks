namespace GeoInfo {

public enum LocationAccuracy {
    UNKNOWN   = -1,
    STREET    =  1000,    /*    1 km */
    CITY      =  15000,   /*   15 km */
    REGION    =  50000,   /*   50 km */
    COUNTRY   =  300000,  /*  300 km */
    CONTINENT = 3000000,  /* 3000 km */
}

public class LocationInfo : GLib.Object {
    public static const double EARTH_RADIUS = 6372.795;
    
    private double _longitude;
    private double _latitude;

    public double longitude {
        get {
            return _longitude;
        }

        set {
            if (-180.0 <= value && value <= 180.0) {
                _longitude = value;
            } else {
                warning ("Longitude is out of range");
            }
        }

        default = 0.0;
    }
    
    public double latitude {
        get {
            return _latitude;
        }

        set {
            if (-90 <= value && value <= 90.0) {
                _latitude = value;
            } else {
                warning ("Latitude is out of range");
            }
        }

        default = 0.0;
    }
            
    public LocationAccuracy accuracy { get; set; default = LocationAccuracy.UNKNOWN; }
    public string? description { get; set; default = null; }
    public string? country_name { get; set; default = null; }
    public string? country_code { get; set; default = null; }
    public uint64 timestamp { get; set; default = 0; }
    
    public LocationInfo (double lat, double lon, LocationAccuracy acc = LocationAccuracy.UNKNOWN) {
        Object (latitude: lat, longitude: lon, accuracy: acc);
    }

}   
} // GeoInfo
