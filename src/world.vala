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
    public GLib.Variant[] locations {
        owned get {
            GLib.Variant[] rv = {};
            GLib.Variant locations = settings.get_value ("world-clocks");

            for (int i = 0; i < locations.n_children (); i++) {
                rv += locations.get_child_value (i).lookup_value ("location", null);
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

    public string name {
        get {
            // We store it in a _name member even if we overwrite it every time
            // since the abstract name property does not return an owned string
            if (country_name != null) {
                if (state_name != null) {
                    _name = "%s, %s, %s".printf (city_name, state_name, country_name);
                } else {
                    _name = "%s, %s".printf (city_name, country_name);
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
            return city_name;
        }
    }

    public string? state_name {
        owned get {
            GWeather.Location? parent = location.get_parent ();

            if (parent != null) {
                if (parent.get_level () == GWeather.LocationLevel.ADM1) {
                    return parent.get_name ();
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
                return weather_info.is_daytime ();
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
            if (!weather_info.get_value_sunrise (out sunrise)) {
                return "-";
            }
            var sunrise_time = new GLib.DateTime.from_unix_local (sunrise);
            sunrise_time = sunrise_time.to_timezone (time_zone);
            return Utils.WallClock.get_default ().format_time (sunrise_time);
        }
    }

    public string sunset_label {
        owned get {
            if (weather_info == null) {
                return "-";
            }

            ulong sunset;
            if (!weather_info.get_value_sunset (out sunset)) {
                return "-";
            }
            var sunset_time = new GLib.DateTime.from_unix_local (sunset);
            sunset_time = sunset_time.to_timezone (time_zone);
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

    // CSS class for the current time of day
    public string state_class {
        get {
            if (date_time.compare (sun_rise) > 0 || date_time.compare (sun_set) < 0) {
                return "day";
            }

            if (date_time.compare (civil_rise) > 0 || date_time.compare (civil_set) < 0) {
                return "civil";
            }

            if (date_time.compare (naut_rise) > 0 || date_time.compare (naut_set) < 0) {
                return "naut";
            }

            if (date_time.compare (astro_rise) > 0 || date_time.compare (astro_set) < 0) {
                return "astro";
            }

            return "night";
        }
    }

    private string _name;
    private GLib.TimeZone time_zone;
    private GLib.DateTime local_time;
    private GLib.DateTime date_time;
    private GWeather.Info weather_info;

    // When sunrise/sunset happens, at different corrections, in locations
    // timezone for calculating the colour pill
    private DateTime sun_rise;
    private DateTime sun_set;
    private DateTime civil_rise;
    private DateTime civil_set;
    private DateTime naut_rise;
    private DateTime naut_set;
    private DateTime astro_rise;
    private DateTime astro_set;
    // When we last calculated
    private int last_calc_day = -1;

    public Item (GWeather.Location location) {
        Object (location: location);

        var weather_time_zone = location.get_timezone ();
        time_zone = new GLib.TimeZone (weather_time_zone.get_tzid ());

        tick ();
    }

    private void calculate_riseset () {
        double lat, lon;
        int y, m, d;
        int rise_hour, rise_min;
        int set_hour, set_min;

        if (date_time.get_day_of_year () == last_calc_day) {
            return;
        }

        location.get_coords (out lat, out lon);

        var utc = date_time.to_utc ();
        utc.get_ymd (out y, out m, out d);

        calculate_sunrise_sunset (lat,
                                  lon,
                                  y,
                                  m,
                                  d,
                                  RISESET_CORRECTION_NONE,
                                  out rise_hour,
                                  out rise_min,
                                  out set_hour,
                                  out set_min);

        sun_rise = new DateTime.utc (y, m, d, rise_hour, rise_min, 0).to_timezone (time_zone);
        sun_set = new DateTime.utc (y, m, d, set_hour, set_min, 0).to_timezone (time_zone);
        if (sun_set.compare (sun_rise) < 0)
            sun_set = sun_set.add_days (1);

        calculate_sunrise_sunset (lat,
                                  lon,
                                  y,
                                  m,
                                  d,
                                  RISESET_CORRECTION_CIVIL,
                                  out rise_hour,
                                  out rise_min,
                                  out set_hour,
                                  out set_min);

        civil_rise = new DateTime.utc (y, m, d, rise_hour, rise_min, 0).to_timezone (time_zone);
        civil_set = new DateTime.utc (y, m, d, set_hour, set_min, 0).to_timezone (time_zone);
        if (civil_set.compare (civil_rise) < 0)
            civil_set = civil_set.add_days (1);

        calculate_sunrise_sunset (lat,
                                  lon,
                                  y,
                                  m,
                                  d,
                                  RISESET_CORRECTION_NAUTICAL,
                                  out rise_hour,
                                  out rise_min,
                                  out set_hour,
                                  out set_min);

        naut_rise = new DateTime.utc (y, m, d, rise_hour, rise_min, 0).to_timezone (time_zone);
        naut_set = new DateTime.utc (y, m, d, set_hour, set_min, 0).to_timezone (time_zone);
        if (naut_set.compare (naut_rise) < 0)
            naut_set = naut_set.add_days (1);

        calculate_sunrise_sunset (lat,
                                  lon,
                                  y,
                                  m,
                                  d,
                                  RISESET_CORRECTION_ASTRONOMICAL,
                                  out rise_hour,
                                  out rise_min,
                                  out set_hour,
                                  out set_min);

        astro_rise = new DateTime.utc (y, m, d, rise_hour, rise_min, 0).to_timezone (time_zone);
        astro_set = new DateTime.utc (y, m, d, set_hour, set_min, 0).to_timezone (time_zone);
        if (astro_set.compare (astro_rise) < 0)
            astro_set = astro_set.add_days (1);
    }

    [Signal (run = "first")]
    public virtual signal void tick () {
        var wallclock = Utils.WallClock.get_default ();
        local_time = wallclock.date_time;
        date_time = local_time.to_timezone (time_zone);

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

    public static ContentItem? deserialize (GLib.Variant location_variant) {
        GWeather.Location? location = null;

        var world = GWeather.Location.get_world ();

        foreach (var v in location_variant) {
            var key = v.get_child_value (0).get_string ();
            if (key == "location") {
                location = world.deserialize (v.get_child_value (1).get_child_value (0));
            }
        }
        return location != null ? new Item (location) : null;
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
            desc.label = "%s • %s".printf (location.day_label, message);
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
private class LocationDialog : Hdy.Dialog {
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

            if (l != null && !world.location_exists (l)) {
                t = l.get_timezone ();

                if (t == null) {
                    GLib.warning ("Timezone not defined for %s. This is a bug in libgweather database",
                                  l.get_city_name ());
                }
            }
        }

        set_response_sensitive (1, l != null && t != null);
    }

    public Item? get_location () {
        var location = location_entry.get_location ();
        return location != null ? new Item (location) : null;
    }
}

[GtkTemplate (ui = "/org/gnome/clocks/ui/world.ui")]
public class Face : Gtk.Stack, Clocks.Clock {
    public PanelId panel_id { get; construct set; }
    public ButtonMode button_mode { get; set; default = NEW; }
    public ViewMode view_mode { get; set; default = NORMAL; }
    public string title { get; set; default = _("Clocks"); }
    public string subtitle { get; set; }
    // Translators: Tooltip for the + button
    public string new_label { get; default = _("Add Location"); }

    private ContentStore locations;
    private GLib.Settings settings;
    private Item standalone_location;
    [GtkChild]
    private Gtk.Widget empty_view;
    [GtkChild]
    private Gtk.ScrolledWindow list_view;
    [GtkChild]
    private Gtk.ListBox listbox;
    [GtkChild]
    private Gtk.Widget standalone;
    [GtkChild]
    private Gtk.Label standalone_time_label;
    [GtkChild]
    private Gtk.Label standalone_day_label;
    [GtkChild]
    private Gtk.Label standalone_sunrise_label;
    [GtkChild]
    private Gtk.Label standalone_sunset_label;

    construct {
        panel_id = WORLD;
        transition_type = CROSSFADE;

        locations = new ContentStore ();
        settings = new GLib.Settings ("org.gnome.clocks");

        locations.set_sorting ((item1, item2) => {
            var offset1 = ((Item) item1).location.get_timezone ().get_offset ();
            var offset2 = ((Item) item2).location.get_timezone ().get_offset ();
            if (offset1 < offset2)
                return -1;
            if (offset1 > offset2)
                return 1;
            return 0;
        });

        listbox.set_header_func ((Gtk.ListBoxUpdateHeaderFunc) Hdy.list_box_separator_header);

        listbox.bind_model (locations, (item) => {
            var tile = new Tile ((Item) item);

            tile.remove_clock.connect (() => locations.delete_item ((Item) item));

            return tile;
        });

        load ();
        show_all ();

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
            update_standalone ();
        });
    }

    [GtkCallback]
    private void item_activated (Gtk.ListBox list, Gtk.ListBoxRow row) {
        show_standalone (((Tile) row).location);
    }

    [GtkCallback]
    private void visible_child_changed () {
        if (visible_child == empty_view || visible_child == list_view) {
            view_mode = NORMAL;
            button_mode = NEW;
            title = _("Clocks");
            subtitle = null;
        } else if (visible_child == standalone) {
            view_mode = STANDALONE;
            button_mode = BACK;
        }
    }

    private void update_standalone () {
        if (standalone_location != null) {
            standalone_time_label.label = standalone_location.time_label;
            standalone_day_label.label = standalone_location.day_label;
            standalone_sunrise_label.label = standalone_location.sunrise_label;
            standalone_sunset_label.label = standalone_location.sunset_label;
        }
    }

    private void show_standalone (Item location) {
        standalone_location = location;
        update_standalone ();
        visible_child = standalone;
        if (standalone_location.state_name != null) {
            title = "%s, %s".printf (standalone_location.city_name, standalone_location.state_name);
        } else {
            title = standalone_location.city_name;
        }
        subtitle = standalone_location.country_name;
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
            var item = (Item)locations.find ((l) => {
                return geo_info.is_location_similar (((Item)l).location);
            });

            if (item != null) {
                return;
            }

            item = new Item (found_location);
            item.automatic = true;
            locations.add (item);
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
            var l = locations.get_object (i) as Item;
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
                add_location_item (location);
            }
            dialog.destroy ();
        });
        dialog.show ();
    }

    public void activate_back () {
        reset_view ();
    }


    public bool escape_pressed () {
        if (visible_child == standalone) {
            reset_view ();
            return true;
        }

        return false;
    }

    public void reset_view () {
        standalone_location = null;
        visible_child = locations.get_n_items () == 0 ? empty_view : list_view;
    }
}

} // namespace World
} // namespace Clocks
