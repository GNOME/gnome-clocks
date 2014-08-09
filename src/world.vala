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

private class Item : Object, ContentItem {
    private static Gdk.Pixbuf? day_pixbuf = Utils.load_image ("day.png");
    private static Gdk.Pixbuf? night_pixbuf = Utils.load_image ("night.png");

    public GWeather.Location location { get; set; }

    public bool automatic { get; set; default = false; }

    public string title_icon { get; set; default = null; }

    public bool selectable { get; set; default = true; }

    public string name {
        get {
            // We store it in a _name member even if we overwrite it every time
            // since the abstract name property does not return an owned string
            if (nation_name != null) {
                _name = "%s, %s".printf (city_name, nation_name);
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

    public string? nation_name {
        owned get {
            var nation = location;

            while (nation != null && nation.get_level () != GWeather.LocationLevel.COUNTRY) {
                nation = nation.get_parent ();
            }

            return nation != null ? nation.get_name () : null;
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
                // If it is Dec 31st here and Jan 1st there (d = 1), then "tomorrow"
                return d == 1 ? _("Tomorrow") : _("Yesterday");
            } else if (d > t) {
                // If it is Jan 1st here and Dec 31st there (t = 1), then "yesterday"
                return t == 1 ? _("Yesterday") : _("Tomorrow");
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
        time_zone = new GLib.TimeZone (weather_time_zone.get_tzid());

        tick ();
    }

    public void tick () {
        var wallclock = Utils.WallClock.get_default ();
        local_time = wallclock.date_time;
        date_time = local_time.to_timezone (time_zone);

        // We don't use the normal constructor since we only want static data
        // and we do not want update() to be called.
        weather_info = (GWeather.Info) Object.new (typeof (GWeather.Info),
                                                   location: location,
                                                   enabled_providers: GWeather.Provider.NONE);
    }

    public void get_thumb_properties (out string text, out string subtext, out Gdk.Pixbuf? pixbuf, out string css_class) {
        text = time_label;
        subtext = day_label;
        if (is_daytime) {
            pixbuf = day_pixbuf;
            css_class = "light";
        } else {
            pixbuf = night_pixbuf;
            css_class = "dark";
        }
    }

    public void serialize (GLib.VariantBuilder builder) {
        builder.open (new GLib.VariantType ("a{sv}"));
        builder.add ("{sv}", "location", location.serialize ());
        builder.close ();
    }

    public static Item deserialize (GLib.Variant location_variant) {
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

[GtkTemplate (ui = "/org/gnome/clocks/ui/worldlocationdialog.ui")]
private class LocationDialog : Gtk.Dialog {
    [GtkChild]
    private GWeather.LocationEntry location_entry;

    public LocationDialog (Gtk.Window parent) {
        Object (transient_for: parent, use_header_bar: 1);
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

            if (l != null) {
                t = l.get_timezone ();

                if (t == null) {
                    GLib.warning ("Timezone not defined for %s. This is a bug in libgweather database", l.get_city_name ());
                }
            }
        }

        set_response_sensitive(1, l != null && t != null);
    }

    public Item? get_location () {
        var location = location_entry.get_location ();
        return location != null ? new Item (location) : null;
    }
}

[GtkTemplate (ui = "/org/gnome/clocks/ui/worldstandalone.ui")]
private class StandalonePanel : Gtk.Grid {
    public Item location { get; set; }

    [GtkChild]
    private Gtk.Label time_label;
    [GtkChild]
    private Gtk.Label day_label;
    [GtkChild]
    private Gtk.Label sunrise_label;
    [GtkChild]
    private Gtk.Label sunset_label;

    public void update () {
        if (location != null) {
            time_label.label = location.time_label;
            day_label.label = location.day_label;
            sunrise_label.label = location.sunrise_label;
            sunset_label.label = location.sunset_label;
        }
    }
}

[GtkTemplate (ui = "/org/gnome/clocks/ui/world.ui")]
public class MainPanel : Gtk.Stack, Clocks.Clock {
    public string label { get; construct set; }
    public HeaderBar header_bar { get; construct set; }
    public PanelId panel_id { get; construct set; }

    private List<Item> locations;
    private GLib.Settings settings;
    private Gtk.Button new_button;
    private Gtk.Button back_button;
    private Gdk.Pixbuf? day_pixbuf;
    private Gdk.Pixbuf? night_pixbuf;
    private ContentView content_view;
    [GtkChild]
    private Gtk.Widget empty_view;
    [GtkChild]
    private StandalonePanel standalone;

    public MainPanel (HeaderBar header_bar) {
        Object (label: _("World"), header_bar: header_bar, transition_type: Gtk.StackTransitionType.CROSSFADE, panel_id: PanelId.WORLD);

        locations = new List<Item> ();
        settings = new GLib.Settings ("org.gnome.clocks");

        day_pixbuf = Utils.load_image ("day.png");
        night_pixbuf = Utils.load_image ("night.png");

        // Translators: "New" refers to a world clock
        new_button = new Gtk.Button.with_label (_("New"));
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
            visible_child = content_view;
        });
        header_bar.pack_start (back_button);

        content_view = new ContentView (empty_view, header_bar);
        content_view.set_sorting(Gtk.SortType.ASCENDING, (item1, item2) => {
            var offset1 = ((Item) item1).location.get_timezone().get_offset();
            var offset2 = ((Item) item2).location.get_timezone().get_offset();
            if (offset1 < offset2)
                return -1;
            if (offset1 > offset2)
                return 1;
            return 0;
        });
        add (content_view);

        content_view.item_activated.connect ((item) => {
            Item location = (Item) item;
            standalone.location = location;
            standalone.update ();
            visible_child = standalone;
        });

        content_view.delete_selected.connect (() => {
            foreach (Object i in content_view.get_selected_items ()) {
                locations.remove ((Item) i);
            }
            save ();
        });

        load ();

        if (settings.get_boolean ("geolocation")) {
            use_geolocation.begin ((obj, res) => {
                use_geolocation.end (res);
            });
        }

        visible_child = content_view;
        show_all ();

        // Start ticking...
        Utils.WallClock.get_default ().tick.connect (() => {
            foreach (var l in locations) {
                l.tick();
            }
            content_view.queue_draw ();
            standalone.update ();
        });
    }

    [GtkCallback]
    private void visible_child_changed () {
        if (visible_child == content_view) {
            header_bar.mode = HeaderBar.Mode.NORMAL;
        } else if (visible_child == standalone) {
            header_bar.mode = HeaderBar.Mode.STANDALONE;
        }
    }

    private void load () {
        foreach (var l in settings.get_value ("world-clocks")) {
            Item? location = Item.deserialize (l);
            if (location != null) {
                locations.prepend (location);
                content_view.add_item (location);
            }
        }
        locations.reverse ();
    }

    private void save () {
        var builder = new GLib.VariantBuilder (new VariantType ("aa{sv}"));
        foreach (Item i in locations) {
            if (!i.automatic) {
                i.serialize (builder);
            }
        }
        settings.set_value ("world-clocks", builder.end ());
    }

    private async void use_geolocation () {
        Geo.Info geo_info = new Geo.Info ();

        geo_info.location_changed.connect ((found_location) => {
            foreach (Item i in locations) {
                if (geo_info.is_location_similar (i.location)) {
                    return;
                }
            }

            var item = new Item (found_location);

            item.automatic = true;
            item.selectable = false;
            item.title_icon = "find-location-symbolic";
            locations.append (item);
            content_view.prepend (item);
        });

        yield geo_info.seek ();
    }

    public void activate_new () {
        var dialog = new LocationDialog ((Gtk.Window) get_toplevel ());

        dialog.response.connect ((dialog, response) => {
            if (response == 1) {
                var location = ((LocationDialog) dialog).get_location ();
                locations.append (location);
                content_view.add_item (location);
                save ();
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
        return content_view.escape_pressed ();
    }

    public void reset_view () {
        visible_child = content_view;
    }

    public void update_header_bar () {
        switch (header_bar.mode) {
        case HeaderBar.Mode.NORMAL:
            new_button.show ();
            content_view.update_header_bar ();
            break;
        case HeaderBar.Mode.SELECTION:
            content_view.update_header_bar ();
            break;
        case HeaderBar.Mode.STANDALONE:
            header_bar.title = GLib.Markup.escape_text (standalone.location.city_name);
            header_bar.subtitle = GLib.Markup.escape_text (standalone.location.nation_name);
            back_button.show ();
            break;
        default:
            assert_not_reached ();
        }
    }
}

} // namespace World
} // namespace Clocks
