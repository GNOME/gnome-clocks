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

public class Item : Object, ContentItem {
    public GWeather.Location location { get; set; }

    public bool automatic { get; set; default = false; }

    public bool selectable { get; set; default = true; }

    public bool selected { get; set; default = false; }

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
            return location.get_city_name ();
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
            return weather_info.is_daytime ();
        }
    }

    public string sunrise_label {
        owned get {
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

    private string _name;
    private GLib.TimeZone time_zone;
    private GLib.DateTime local_time;
    private GLib.DateTime date_time;
    private GWeather.Info weather_info;

    public Item (GWeather.Location location) {
        Object (location: location);

        var weather_time_zone = location.get_timezone ();
        time_zone = new GLib.TimeZone (weather_time_zone.get_tzid ());

        tick ();
    }

    [Signal (run = "first")]
    public virtual signal void tick () {
        var wallclock = Utils.WallClock.get_default ();
        local_time = wallclock.date_time;
        date_time = local_time.to_timezone (time_zone);

        // We don't use the normal constructor since we only want static data
        // and we do not want update() to be called.
        weather_info = (GWeather.Info) Object.new (typeof (GWeather.Info),
                                                   location: location,
                                                   enabled_providers: GWeather.Provider.NONE);
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
private class Tile : Gtk.Grid {
    private static Gdk.Pixbuf? day_pixbuf = Utils.load_image ("day.png");
    private static Gdk.Pixbuf? night_pixbuf = Utils.load_image ("night.png");

    public Item location { get; construct set; }

    [GtkChild]
    private Gtk.Image image;
    [GtkChild]
    private Gtk.Label time_label;
    [GtkChild]
    private Gtk.Widget name_icon;
    [GtkChild]
    private Gtk.Widget name_label;

    public Tile (Item location) {
        Object (location: location);

        location.bind_property ("automatic", name_icon, "visible", BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE);
        location.bind_property ("name", name_label, "label", BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE);
        location.tick.connect (update);

        update ();
    }

    private void update () {
        if (location.is_daytime) {
            get_style_context ().remove_class ("night");
            image.pixbuf = day_pixbuf;
        } else {
            get_style_context ().add_class ("night");
            image.pixbuf = night_pixbuf;
        }

        if (location.day_label != null && location.day_label != "") {
            time_label.label = "%s\n<span size='xx-small'>%s</span>".printf (location.time_label, location.day_label);
        } else {
            time_label.label = location.time_label;
        }
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
    public string label { get; construct set; }
    public HeaderBar header_bar { get; construct set; }
    public PanelId panel_id { get; construct set; }

    private ContentStore locations;
    private GLib.Settings settings;
    private Gtk.Button new_button;
    private Gtk.Button back_button;
    private Item standalone_location;
    [GtkChild]
    private Gtk.Widget empty_view;
    [GtkChild]
    private ContentView content_view;
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

    public Face (HeaderBar header_bar) {
        Object (label: _("World"),
                header_bar: header_bar,
                panel_id: PanelId.WORLD,
                transition_type: Gtk.StackTransitionType.CROSSFADE);

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

        // Translators: "New" refers to a world clock
        new_button = new Gtk.Button.with_label (C_("World clock", "New"));
        new_button.valign = Gtk.Align.CENTER;
        new_button.no_show_all = true;
        new_button.action_name = "win.new";
        header_bar.pack_start (new_button);

        back_button = new Gtk.Button ();
        var back_button_image = new Gtk.Image.from_icon_name ("go-previous-symbolic", Gtk.IconSize.MENU);
        back_button.valign = Gtk.Align.CENTER;
        back_button.set_image (back_button_image);
        back_button.no_show_all = true;
        back_button.clicked.connect (() => {
            reset_view ();
        });
        header_bar.pack_start (back_button);

        content_view.bind_model (locations, (item) => {
            return new Tile ((Item)item);
        });

        content_view.set_header_bar (header_bar);

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
            content_view.queue_draw ();
            update_standalone ();
        });
    }

    [GtkCallback]
    private void item_activated (ContentItem item) {
        show_standalone ((Item) item);
    }

    [GtkCallback]
    private void visible_child_changed () {
        if (visible_child == empty_view || visible_child == content_view) {
            header_bar.mode = HeaderBar.Mode.NORMAL;
        } else if (visible_child == standalone) {
            header_bar.mode = HeaderBar.Mode.STANDALONE;
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
            item.selectable = false;
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

    public void activate_select_all () {
        content_view.select_all ();
    }

    public void activate_select_none () {
        content_view.unselect_all ();
    }

    public bool escape_pressed () {
        if (visible_child == standalone) {
            reset_view ();
            return true;
        }

        return content_view.escape_pressed ();
    }

    public void back () {
        if (visible_child == standalone) {
            reset_view ();
        }
    }

    public void reset_view () {
        standalone_location = null;
        visible_child = locations.get_n_items () == 0 ? empty_view : content_view;
        request_header_bar_update ();
    }

    public void update_header_bar () {
        switch (header_bar.mode) {
        case HeaderBar.Mode.NORMAL:
            header_bar.title = _("Clocks");
            header_bar.subtitle = null;
            new_button.show ();
            content_view.update_header_bar ();
            break;
        case HeaderBar.Mode.SELECTION:
            content_view.update_header_bar ();
            break;
        case HeaderBar.Mode.STANDALONE:
            if (standalone_location.state_name != null) {
                header_bar.title = "%s, %s".printf (standalone_location.city_name, standalone_location.state_name);
            } else {
                header_bar.title = standalone_location.city_name;
            }
            header_bar.subtitle = standalone_location.country_name;
            back_button.show ();
            break;
        default:
            assert_not_reached ();
        }
    }
}

} // namespace World
} // namespace Clocks
