/*
 * Copyright (C) 2013  Paolo Borelli <pborelli@gnome.org>
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
namespace World {

public enum SunState {
    NONE,
    NIGHT,
    ASTRO,
    NAUT,
    CIVIL,
    DAY;

    internal string as_css () {
        switch (this) {
            case NONE:
            default:
                return "none";
            case NIGHT:
                return "night";
            case ASTRO:
                return "astro";
            case NAUT:
                return "naut";
            case CIVIL:
                return "civil";
            case DAY:
                return "day";
        }
    }
}

internal const string[] STATE_CLASSES = {
    "none",
    "night",
    "astro",
    "naut",
    "civil",
    "day",
};

public class Item : Object, ContentItem {
    public GWeather.Location location { get; set; }

    public bool automatic { get; set; default = false; }

    public string? name {
        get {
            // We store it in a _name member even if we overwrite it every time
            // since the abstract name property does not return an owned string
            if (country_name != null) {
                if (state_name != null) {
                    _name = "%s, %s, %s".printf (city_name, (string) state_name, (string) country_name);
                } else {
                    _name = "%s, %s".printf (city_name, (string) country_name);
                }
            } else {
                _name = city_name;
            }

            return _name;
        }
        set {
            // ignored
        }
    }

    public string city_name {
        owned get {
            var city_name = location.get_city_name ();
            /* Named Timezones don't have city names */
            if (city_name == null) {
                city_name = location.get_name ();
            }
            return (string) city_name;
        }
    }

    public string? state_name {
        owned get {
            GWeather.Location? parent = location.get_parent ();

            if (parent != null) {
                if (((GWeather.Location) parent).get_level () == ADM1) {
                    return ((GWeather.Location) parent).get_name ();
                }
            }

            return null;
        }
    }

    public string? country_name {
        owned get {
            return location.get_country_name ();
        }
    }

    public string sunrise_label {
        owned get {
            if (weather_info == null) {
                return "-";
            }

            ulong sunrise;
            if (!((GWeather.Info) weather_info).get_value_sunrise (out sunrise)) {
                return "-";
            }

            if (time_zone == null) {
                return "-";
            }

            var sunrise_time = new GLib.DateTime.from_unix_local (sunrise);
            sunrise_time = sunrise_time.to_timezone ((TimeZone) time_zone);
            return Utils.WallClock.get_default ().format_time (sunrise_time, false);
        }
    }

    public string sunset_label {
        owned get {
            if (weather_info == null) {
                return "-";
            }

            ulong sunset;
            if (!((GWeather.Info) weather_info).get_value_sunset (out sunset)) {
                return "-";
            }

            if (time_zone == null) {
                return "-";
            }

            var sunset_time = new GLib.DateTime.from_unix_local (sunset);
            sunset_time = sunset_time.to_timezone ((TimeZone) time_zone);
            return Utils.WallClock.get_default ().format_time (sunset_time, false);
        }
    }

    public string time_label {
        owned get {
            return Utils.WallClock.get_default ().format_time (date_time, false);
        }
    }

    public string time_label_seconds {
        owned get {
            return Utils.WallClock.get_default ().format_time (date_time, true);
        }
    }

    public string? day_label {
        get {
            var d = date_time.get_day_of_year ();
            var t = local_time.get_day_of_year ();

            if (d < t) {
                // If it is Jan 1st there, and not Jan 2nd here, then it must be
                // Dec 31st here, so return "tomorrow"
                return (d == 1 && t != 2) ? _("Tomorrow") : _("Yesterday");
            } else if (d > t) {
                // If it is Jan 1st here, and not Jan 2nd there, then it must be
                // Dec 31st there, so return "yesterday"
                return (t == 1 && d != 2) ? _("Yesterday") : _("Tomorrow");
            } else {
                return null;
            }
        }
    }

    public TimeSpan local_offset {
        get {
            return local_time.get_utc_offset () - date_time.get_utc_offset ();
        }
    }

    private bool is_current (DateTime? sunrise, DateTime? sunset) {
        if (sunrise == null || sunset == null) {
            return false;
        }

        return (date_time.compare ((DateTime) sunrise) > 0) &&
                        (date_time.compare ((DateTime) sunset) < 0);
    }

    // CSS class for the current time of day
    public SunState sun_state {
        get {
            if (sun_rise == null || sun_set == null) {
                return NONE;
            }

            if (is_current (sun_rise, sun_set)) {
                return DAY;
            }

            if (is_current (civil_rise, civil_set)) {
                return CIVIL;
            }

            if (is_current (naut_rise, naut_set)) {
                return NAUT;
            }

            if (is_current (astro_rise, astro_set)) {
                return ASTRO;
            }

            return NIGHT;
        }
    }

    private string _name;
    private GLib.TimeZone? time_zone;
    private GLib.DateTime local_time;
    private GLib.DateTime date_time;
    private GWeather.Info? weather_info;

    // When sunrise/sunset happens, at different corrections, in locations
    // timezone for calculating the colour pill
    private DateTime? sun_rise;
    private DateTime? sun_set;
    private DateTime? civil_rise;
    private DateTime? civil_set;
    private DateTime? naut_rise;
    private DateTime? naut_set;
    private DateTime? astro_rise;
    private DateTime? astro_set;
    // When we last calculated
    private int last_calc_day = -1;

    public Item (GWeather.Location location) {
        Object (location: location);

        time_zone = location.get_timezone ();

        tick ();
    }

    private void calculate_riseset_at_correction (double latitude,
                                                  double longitude,
                                                  int year,
                                                  int month,
                                                  int day,
                                                  double correction,
                                                  out DateTime? sunrise,
                                                  out DateTime? sunset) requires (time_zone != null) {
        int rise_hour, rise_min;
        int set_hour, set_min;

        if (!calculate_sunrise_sunset (latitude,
                                       longitude,
                                       year,
                                       month,
                                       day,
                                       correction,
                                       out rise_hour,
                                       out rise_min,
                                       out set_hour,
                                       out set_min)) {
            sunrise = null;
            sunset = null;
            debug ("Location (%f,%f) has incalculable sunset/sunrise",
                   latitude,
                   longitude);
            return;
        }

        var utc_sunrise = (DateTime?) new DateTime.utc (year, month, day, rise_hour, rise_min, 0);
        if (utc_sunrise != null) {
            sunrise = ((DateTime) utc_sunrise).to_timezone ((TimeZone) time_zone);
        } else {
            sunrise = null;
            warning ("Sunrise for (%f,%f) resulted in %04i-%02i-%02i %02i:%02i",
                     latitude,
                     longitude,
                     year,
                     month,
                     day,
                     rise_hour,
                     rise_min);
        }

        var utc_sunset = (DateTime?) new DateTime.utc (year, month, day, set_hour, set_min, 0);
        if (utc_sunset != null && sunrise != null) {
            var local_sunset = ((DateTime) utc_sunset).to_timezone ((TimeZone) time_zone);
            if (local_sunset.compare ((DateTime) sunrise) < 0) {
                sunset = local_sunset.add_days (1);
            } else {
                sunset = local_sunset;
            }
        } else {
            sunset = null;
            warning ("Sunset for (%f,%f) resulted in %04i-%02i-%02i %02i:%02i",
                     latitude,
                     longitude,
                     year,
                     month,
                     day,
                     rise_hour,
                     rise_min);
        }
    }

    private void calculate_riseset () {
        // Where we are calculating for
        double latitude, longitude;
        // The current UTC day
        int year, month, day;

        if (date_time.get_day_of_year () == last_calc_day) {
            return;
        }

        if (!location.has_coords ()) {
            return;
        }

        location.get_coords (out latitude, out longitude);

        // Some locations, such as UTC, aren't actual locations and don't have
        // proper coords
        if (!latitude.is_finite () || !longitude.is_finite ()) {
            return;
        }

        var utc = date_time.to_utc ();
        utc.get_ymd (out year, out month, out day);

        calculate_riseset_at_correction (latitude,
                                         longitude,
                                         year,
                                         month,
                                         day,
                                         RISESET_CORRECTION_NONE,
                                         out sun_rise,
                                         out sun_set);
        calculate_riseset_at_correction (latitude,
                                         longitude,
                                         year,
                                         month,
                                         day,
                                         RISESET_CORRECTION_CIVIL,
                                         out civil_rise,
                                         out civil_set);
        calculate_riseset_at_correction (latitude,
                                         longitude,
                                         year,
                                         month,
                                         day,
                                         RISESET_CORRECTION_NAUTICAL,
                                         out naut_rise,
                                         out naut_set);
        calculate_riseset_at_correction (latitude,
                                         longitude,
                                         year,
                                         month,
                                         day,
                                         RISESET_CORRECTION_ASTRONOMICAL,
                                         out astro_rise,
                                         out astro_set);

        last_calc_day = date_time.get_day_of_year ();
    }

    [Signal (run = "first")]
    public virtual signal void tick () {
        var wallclock = Utils.WallClock.get_default ();
        local_time = wallclock.date_time;

        if (time_zone == null) {
            return;
        }

        date_time = local_time.to_timezone ((TimeZone) time_zone);

        calculate_riseset ();

        // We don't use the normal constructor since we only want static data
        // and we do not want update() to be called.
        if (location.has_coords ()) {
            weather_info = (GWeather.Info) Object.new (typeof (GWeather.Info),
                                                       location: location,
                                                       enabled_providers: GWeather.Provider.NONE);
        }

        notify_property ("sunrise-label");
        notify_property ("sunset-label");
        notify_property ("time-label");
        notify_property ("time-label-seconds");
        notify_property ("day-label");
        notify_property ("local-offset");
        notify_property ("sun-state");
    }

    public void serialize (GLib.VariantBuilder builder) {
        if (!automatic) {
            builder.open (new GLib.VariantType ("a{sv}"));
            builder.add ("{sv}", "location", location.serialize ());
            builder.close ();
        }
    }

    public static ContentItem? deserialize (Variant location_variant) {
        GWeather.Location? location = null;
        string key;
        Variant val;
        var world = GWeather.Location.get_world ();

        if (world == null) {
            return null;
        }

        var iter = location_variant.iterator ();
        while (iter.next ("{sv}", out key, out val)) {
            if (key == "location") {
                location = ((GWeather.Location) world).deserialize (val);
            }
        }

        if (location == null) {
            return null;
        } else if (((GWeather.Location) location).get_timezone_str () == null) {
            warning ("Invalid location “%s” – timezone unknown. Ignoring.",
                     ((GWeather.Location) location).get_name ());
            return null;
        } else {
            return new Item ((GWeather.Location) location);
        }
    }
}

} // namespace World
} // namespace Clocks
