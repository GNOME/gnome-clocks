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
public class Face : Gtk.Stack, Clocks.Clock {
    public signal void show_standalone (Item location);

    public PanelId panel_id { get; construct set; }
    public ButtonMode button_mode { get; set; default = NEW; }
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
