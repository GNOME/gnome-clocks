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

// Export world clock locations to GNOME Shell
[DBus (name = "org.gnome.Shell.ClocksIntegration")]
public class ShellWorldClocks : Object {
    [DBus (signature = "av")]
    public Variant locations {
        owned get {
            Variant dict;
            Variant[] rv = {};
            var locations = settings.get_value ("world-clocks");
            var iter = locations.iterator ();

            while (iter.next ("@a{sv}", out dict)) {
                string key;
                Variant val;
                var dict_iter = dict.iterator ();
                while (dict_iter.next ("{sv}", out key, out val)) {
                    if (key == "location") {
                        rv += val;
                    }
                }
            }

            return rv;
        }
    }

    private DBusConnection connection;
    private string object_path;

    private GLib.Settings settings;

    public ShellWorldClocks (DBusConnection connection, string object_path) {
        this.connection = connection;
        this.object_path = object_path;

        settings = new GLib.Settings ("org.gnome.clocks");
        settings.changed["world-clocks"].connect (() => {
            var builder = new VariantBuilder (VariantType.ARRAY);
            var invalid_builder = new VariantBuilder (new VariantType ("as"));

            Variant v = locations;
            builder.add ("{sv}", "Locations", v);

            try {
                this.connection.emit_signal (null,
                                            this.object_path,
                                            "org.freedesktop.DBus.Properties",
                                            "PropertiesChanged",
                                            new Variant ("(sa{sv}as)",
                                                        "org.gnome.Shell.ClocksIntegration",
                                                        builder,
                                                        invalid_builder));
            } catch (Error e) {
                warning ("Shell Integration failed: %s", e.message);
            }
        });
    }
}

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

    public bool is_daytime {
         get {
            if (weather_info != null) {
                return ((GWeather.Info) weather_info).is_daytime ();
            }
            return true;
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
            return Utils.WallClock.get_default ().format_time (sunrise_time);
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
            return Utils.WallClock.get_default ().format_time (sunset_time);
        }
    }

    public string time_label {
        owned get {
            return Utils.WallClock.get_default ().format_time (date_time);
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
    public string state_class {
        get {
            if (sun_rise == null || sun_set == null) {
                return "none";
            }

            if (is_current (sun_rise, sun_set)) {
                return "day";
            }

            if (is_current (civil_rise, civil_set)) {
                return "civil";
            }

            if (is_current (naut_rise, naut_set)) {
                return "naut";
            }

            if (is_current (astro_rise, astro_set)) {
                return "astro";
            }

            return "night";
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

        var weather_time_zone = location.get_timezone_str ();
        if (weather_time_zone != null) {
            time_zone = new GLib.TimeZone ((string) weather_time_zone);
            if (time_zone == null) {
                warning ("Unrecognised timezone %s", (string) weather_time_zone);
            }
        } else {
            warning ("Failed to get a timezone for %s", location.get_name ());
        }

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

        return location == null ? null : (Item?) new Item ((GWeather.Location) location);
    }
}

[GtkTemplate (ui = "/org/gnome/clocks/ui/worldtile.ui")]
private class Tile : Gtk.ListBoxRow {
    public Item location { get; construct set; }

    [GtkChild]
    private Gtk.Label time_label;
    [GtkChild]
    private Gtk.Widget name_label;
    [GtkChild]
    private Gtk.Label desc;
    [GtkChild]
    private Gtk.Stack delete_stack;
    [GtkChild]
    private Gtk.Widget delete_button;
    [GtkChild]
    private Gtk.Widget delete_empty;

    internal signal void remove_clock ();

    public Tile (Item location) {
        Object (location: location);

        location.bind_property ("city-name", name_label, "label", BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE);
        location.tick.connect (update);

        update ();
    }

    private void update () {
        var ctx = get_style_context ();
        ctx.remove_class ("night");
        ctx.remove_class ("astro");
        ctx.remove_class ("naut");
        ctx.remove_class ("civil");
        ctx.remove_class ("day");
        ctx.add_class (location.state_class);

        var diff = ((double) location.local_offset / (double) TimeSpan.HOUR);
        var diff_string = "%.0f".printf (diff.abs ());

        if (diff != Math.round (diff)) {
            diff_string = "%.1f".printf (diff.abs ());
        }

        // Translators: The time is the same as the local time
        var message = _("Current timezone");

        if (diff > 0) {
            // Translators: The (possibly fractical) number hours in the past
            // (relative to local) the clock/location is
            message = ngettext ("%s hour earlier",
                                "%s hours earlier",
                                ((int) diff).abs ()).printf (diff_string);
        } else if (diff < 0) {
            // Translators: The (possibly fractical) number hours in the
            // future (relative to local) the clock/location is
            message = ngettext ("%s hour later",
                                "%s hours later",
                                ((int) diff).abs ()).printf (diff_string);
        }

        if (location.day_label != null && location.day_label != "") {
            desc.label = "%s • %s".printf ((string) location.day_label, message);
            delete_stack.visible_child = delete_button;
        } else if (location.automatic) {
            // Translators: This clock represents the local time
            desc.label = _("Current location");
            delete_stack.visible_child = delete_empty;
        } else {
            desc.label = "%s".printf (message);
            delete_stack.visible_child = delete_button;
        }

        time_label.label = location.time_label;
    }

    [GtkCallback]
    private void delete () {
        remove_clock ();
    }
}

[GtkTemplate (ui = "/org/gnome/clocks/ui/worldlocationdialog.ui")]
private class LocationDialog : Gtk.Dialog {
    [GtkChild]
    private GWeather.LocationEntry location_entry;
    private Face world;

    public LocationDialog (Gtk.Window parent, Face world_face) {
        Object (transient_for: parent, use_header_bar: 1);

        world = world_face;
    }

    [GtkCallback]
    private void icon_released () {
        if (location_entry.secondary_icon_name == "edit-clear-symbolic") {
            location_entry.set_text ("");
        }
    }

    [GtkCallback]
    private void location_changed () {
        GWeather.Location? l = null;
        GWeather.Timezone? t = null;

        if (location_entry.get_text () != "") {
            l = location_entry.get_location ();

            if (l != null && !world.location_exists ((GWeather.Location) l)) {
                t = ((GWeather.Location) l).get_timezone ();

                if (t == null) {
                    warning ("Timezone not defined for %s. This is a bug in libgweather database",
                             (string) ((GWeather.Location) l).get_city_name ());
                }
            }
        }

        set_response_sensitive (1, l != null && t != null);
    }

    public Item? get_location () {
        var location = location_entry.get_location ();
        return location != null ? (Item?) new Item ((GWeather.Location) location) : null;
    }
}

[GtkTemplate (ui = "/org/gnome/clocks/ui/world.ui")]
public class Face : Gtk.Stack, Clocks.Clock {
    public signal void show_standalone (Item location);

    public PanelId panel_id { get; construct set; }
    public ButtonMode button_mode { get; set; default = NEW; }
    public ViewMode view_mode { get; set; default = NORMAL; }
    public string title { get; set; default = _("Clocks"); }
    public string subtitle { get; set; }
    // Translators: Tooltip for the + button
    public string? new_label { get; default = _("Add Location"); }

    private ContentStore locations;
    private GLib.Settings settings;
    [GtkChild]
    private Gtk.Widget empty_view;
    [GtkChild]
    private Gtk.ScrolledWindow list_view;
    [GtkChild]
    private Gtk.ListBox listbox;

    construct {
        panel_id = WORLD;
        transition_type = CROSSFADE;

        locations = new ContentStore ();
        settings = new GLib.Settings ("org.gnome.clocks");

        locations.set_sorting ((item1, item2) => {
            var offset1 = ((GWeather.Timezone) ((Item) item1).location.get_timezone ()).get_offset ();
            var offset2 = ((GWeather.Timezone) ((Item) item2).location.get_timezone ()).get_offset ();
            if (offset1 < offset2)
                return -1;
            if (offset1 > offset2)
                return 1;
            return 0;
        });

        listbox.bind_model (locations, (item) => {
            var tile = new Tile ((Item) item);

            tile.remove_clock.connect (() => locations.delete_item ((Item) item));

            return tile;
        });

        load ();

        if (settings.get_boolean ("geolocation")) {
            use_geolocation.begin ((obj, res) => {
                use_geolocation.end (res);
            });
        }

        locations.items_changed.connect ((position, removed, added) => {
            save ();
            reset_view ();
        });

        reset_view ();

        // Start ticking...
        Utils.WallClock.get_default ().tick.connect (() => {
            locations.foreach ((l) => {
                ((Item)l).tick ();
            });
            // TODO Only need to queue what changed
            listbox.queue_draw ();
        });
    }

    [GtkCallback]
    private void item_activated (Gtk.ListBox list, Gtk.ListBoxRow row) {
        show_standalone (((Tile) row).location);
    }

    private void load () {
        locations.deserialize (settings.get_value ("world-clocks"), Item.deserialize);
    }

    private void save () {
        settings.set_value ("world-clocks", locations.serialize ());
    }

    private async void use_geolocation () {
        Geo.Info geo_info = new Geo.Info ();

        geo_info.location_changed.connect ((found_location) => {
            var item = (Item?) locations.find ((l) => {
                return geo_info.is_location_similar (((Item) l).location);
            });

            if (item != null) {
                return;
            }

            var auto_item = new Item (found_location);
            auto_item.automatic = true;
            locations.add (auto_item);
        });

        yield geo_info.seek ();
    }

    private void add_location_item (Item item) {
        locations.add (item);
        save ();
    }

    public bool location_exists (GWeather.Location location) {
        var exists = false;
        var n = locations.get_n_items ();
        for (int i = 0; i < n; i++) {
            var l = (Item) locations.get_object (i);
            if (l.location.equal (location)) {
                exists = true;
                break;
            }
        }

        return exists;
    }

    public void add_location (GWeather.Location location) {
        if (!location_exists (location)) {
            add_location_item (new Item (location));
        }
    }

    public void activate_new () {
        var dialog = new LocationDialog ((Gtk.Window) get_toplevel (), this);

        dialog.response.connect ((dialog, response) => {
            if (response == 1) {
                var location = ((LocationDialog) dialog).get_location ();
                add_location_item ((Item) location);
            }
            dialog.destroy ();
        });
        dialog.show ();
    }

    private void reset_view () {
        visible_child = locations.get_n_items () == 0 ? empty_view : list_view;
    }
}

} // namespace World
} // namespace Clocks
