namespace GeoInfo {

public class LocationMonitor : GLib.Object {
    private string? ip_address;
    private Soup.SessionAsync session;

    private string _server;
    public string server { 
        get { return _server; }
        set {
            if (value.has_prefix ("http://") ||
                value.has_prefix ("https://")) {
                _server = value;
            } else {
                warning ("Server path does not begins with \"http://\" either with \"https://\"");
            }
        }
    }

    public bool compatibility_mode { get; set; }
    
    public LocationMonitor () {
        ip_address = null;
        server = "http://freegeoip.net/json/";
        compatibility_mode = true;
        
        session = new Soup.SessionAsync ();
        session.use_thread_context = true;
    }

    public async GeoInfo.LocationInfo? search () {
        Soup.Message query = get_search_query ();
        GLib.InputStream stream;
        try {
            stream = yield session.send_async (query);
        } catch (Error e) {
            warning ("Unable to sent message: %s", e.message);
            return null;
        }

        var parser = new Json.Parser ();
 
        try {
            parser.load_from_stream (stream);
        } catch (Error e) {
            warning ("Failed to load data from stream: %s", e.message);
            return null;
        }

        var root_object = parser.get_root ().get_object ();
          
        if (root_object.has_member ("error_code")) {
            warning ("Response from the server contains an error");
            return null;
        }

        double latitude = root_object.get_double_member ("latitude");
        double longitude = root_object.get_double_member ("longitude");
        LocationAccuracy accuracy = parse_accuracy (root_object);
            
        var location = new GeoInfo.LocationInfo (latitude, longitude, accuracy);
        
        location.description = parse_description (root_object);
        
        return location;
    }

    private LocationAccuracy parse_accuracy (Json.Object object) {
        if (object.has_member ("accuracy")) {
                string str = object.get_string_member ("accuracy");
                return get_accuracy_from_string (str);
        } else if (object.has_member ("street")) {
                return LocationAccuracy.STREET;
        } else if (object.has_member ("city")) {
                return LocationAccuracy.CITY;
        } else if (object.has_member ("region_name")) {
                return LocationAccuracy.REGION;
        } else if (object.has_member ("country_name")) {
                return LocationAccuracy.COUNTRY;
        } else if (object.has_member ("continent")) {
                return LocationAccuracy.CONTINENT;
        } else {
                return LocationAccuracy.UNKNOWN;
        }
    }

    private LocationAccuracy get_accuracy_from_string (string str)
    {
        switch (str) {
        case "street":
            return LocationAccuracy.STREET;
        case "city":
            return LocationAccuracy.CITY;
        case "region":
            return LocationAccuracy.REGION;
        case "country":
            return LocationAccuracy.COUNTRY;
        case "continent":
            return LocationAccuracy.CONTINENT;
        default:
            return LocationAccuracy.UNKNOWN;
        }
    }

    private string? parse_description (Json.Object object) {
        string? desc = null;
        if (object.has_member ("country_name")) {
            if (object.has_member ("region_name")) {
                if (object.has_member ("city")) {
                    desc = "%s, %s, %s".printf (object.get_string_member ("city"),
                                                object.get_string_member ("region_name"),
                                                object.get_string_member ("country_name"));
                } else {
                    desc = "%s, %s".printf (object.get_string_member ("region_name"),
                                            object.get_string_member ("country_name"));
                }
            } else {
                desc = object.get_string_member ("country_name");
            }
        }
        return desc;
    }

    private Soup.Message get_search_query () {
        string uri;

        if (ip_address != null) {
            if (compatibility_mode) {
                string escaped = Soup.URI.encode (ip_address, null);
                uri = @"$server/$escaped";
            } else {
                var ht = new HashTable<string, string> (GLib.str_hash, GLib.str_equal);
                ht.insert ("ip", ip_address);
                string query = Soup.Form.encode_hash (ht);
                uri = @"$server?$query";
            }
        } else
            uri = server;

        return new Soup.Message ("GET", uri);
    }
}    
} // GeoInfo
