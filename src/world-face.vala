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

[GtkTemplate (ui = "/org/gnome/clocks/ui/world-face.ui")]
public class Face : Adw.Bin, Clocks.Clock {
    public signal void show_standalone (Item location);

    public PanelId panel_id { get; construct set; }
    public ButtonMode button_mode { get; set; default = NEW; }
    // Translators: Tooltip for the + button
    public string? new_label { get; default = _("Add Location"); }

    private ContentStore locations;
    private Gtk.SortListModel sorted_locations;
    private GLib.Settings settings;
    [GtkChild]
    private unowned Gtk.Widget empty_view;
    [GtkChild]
    private unowned Gtk.ScrolledWindow list_view;
    [GtkChild]
    private unowned Gtk.ListBox listbox;
    [GtkChild]
    private unowned Gtk.Stack stack;

    construct {
        panel_id = WORLD;

        var unixtime = new GLib.DateTime.now_local ().to_unix ();

        locations = new ContentStore ();
        sorted_locations = new Gtk.SortListModel (
            locations,
            new Gtk.CustomSorter ((item1, item2) => {
                var interval1 = ((Item) item1).location.get_timezone ().find_interval (GLib.TimeType.STANDARD, unixtime);
                var offset1 = ((Item) item1).location.get_timezone ().get_offset (interval1);
                var interval2 = ((Item) item2).location.get_timezone ().find_interval (GLib.TimeType.STANDARD, unixtime);
                var offset2 = ((Item) item2).location.get_timezone ().get_offset (interval2);
                if (offset1 < offset2)
                    return -1;
                if (offset1 > offset2)
                    return 1;
                return 0;
            })
        );

        settings = new GLib.Settings ("org.gnome.clocks");

        listbox.bind_model (sorted_locations, (item) => {
            var row = new Row ((Item) item);

            row.remove_clock.connect (() => locations.delete_item ((Item) item));

            return row;
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
        show_standalone (((Row) row).location);
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
        var dialog = new LocationDialog (this);

        dialog.location_added.connect (() => {
                var location = dialog.get_selected_location ();
                if (location != null)
                    add_location ((GWeather.Location) location);

                dialog.force_close ();
            });
        dialog.present (get_root ());
    }

    private void reset_view () {
        stack.visible_child = locations.get_n_items () == 0 ? empty_view : list_view;
    }
}

} // namespace World
} // namespace Clocks
