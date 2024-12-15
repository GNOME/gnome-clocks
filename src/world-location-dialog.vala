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

private class ClockLocation : Object {
    public GWeather.Location location { get; construct set; }
    public bool selected { get; set; }

    public ClockLocation (GWeather.Location location, bool selected) {
        Object (location: location, selected: selected);
    }
}

[GtkTemplate (ui = "/org/gnome/clocks/ui/world-location-dialog.ui")]
private class LocationDialog : Adw.Dialog {
    [GtkChild]
    private unowned Gtk.Stack stack;
    [GtkChild]
    private unowned Gtk.Widget empty_search;
    [GtkChild]
    private unowned Gtk.Widget search_results;
    [GtkChild]
    private unowned Gtk.SearchEntry location_entry;
    [GtkChild]
    private unowned Gtk.ListBox listbox;
    [GtkChild]
    private unowned Gtk.Button button_add;

    private Face world;
    private ListStore locations;
    private LocationDialogRow? _selected_row = null;
    private LocationDialogRow? selected_row {
        get {
            return _selected_row;
        } set {
            _selected_row = value;
            button_add.sensitive = _selected_row != null;
        }
    }

    private const int RESULT_COUNT_LIMIT = 12;

    public LocationDialog (Face world_face) {
        // HACK: We set the key capture widget on the entry
        // rather than the search bar. This way when pressing
        // TAB the widget will continue to get input events.
        location_entry.set_key_capture_widget (this);

        world = world_face;

        locations = new ListStore (typeof (ClockLocation));
        listbox.bind_model (locations, (data) => {
            return new LocationDialogRow ((ClockLocation) data);
        });
    }

    public GWeather.Location? get_selected_location () {
        if (selected_row == null)
            return null;
        return ((LocationDialogRow) selected_row).data.location;
    }

    [GtkCallback]
    private void on_search_mode_notify (GLib.Object object, GLib.ParamSpec param) {
        // Pressing ESC will close the search bar, we don't want that.
        var search_bar = (Gtk.SearchBar) object;
        if (!search_bar.search_mode_enabled)
            search_bar.search_mode_enabled = true;
    }

    [GtkCallback]
    private void item_activated (Gtk.ListBoxRow listbox_row) {
        var row = (LocationDialogRow) listbox_row;

        if (selected_row != null && selected_row != row) {
            ((LocationDialogRow) selected_row).data.selected = false;
        }

        row.data.selected = !row.data.selected;
        if (row.data.selected) {
            selected_row = row;
        } else {
            selected_row = null;
        }
    }

    [GtkCallback]
    private void on_search_changed () {
        selected_row = null;

        // Remove old results
        locations.remove_all ();

        if (location_entry.text == "") {
            stack.visible_child = empty_search;
            return;
        }

        string search = location_entry.text.normalize ().casefold ();
        var world_location = GWeather.Location.get_world ();
        if (world_location == null) {
            return;
        }

        query_locations ((GWeather.Location) world_location, search);

        if (locations.get_n_items () == 0) {
            stack.visible_child = empty_search;
            return;
        }
        locations.sort ((a, b) => {
            var name_a = ((ClockLocation) a).location.get_sort_name ();
            var name_b = ((ClockLocation) b).location.get_sort_name ();
            return strcmp (name_a, name_b);
        });

        stack.visible_child = search_results;
    }

    public signal void location_added ();

    [GtkCallback]
    private void add_button_clicked () {
        location_added ();
    }

    private void query_locations (GWeather.Location location, string search) {
        if (locations.get_n_items () >= RESULT_COUNT_LIMIT) return;

        switch (location.get_level ()) {
            case CITY:
                var contains_name = location.get_sort_name ().contains (search);
                if (!contains_name) {
                    contains_name = location.get_english_sort_name ().to_ascii ().contains (search);
                }

                var country_name = location.get_country_name ();
                if (country_name != null) {
                    country_name = ((string) country_name).normalize ().casefold ();
                }
                var contains_country_name = country_name != null && ((string) country_name).contains (search);

                if (contains_name || contains_country_name) {
                    bool selected = world.location_exists (location);
                    locations.append (new ClockLocation (location, selected));
                }
                return;
            case NAMED_TIMEZONE:
                if (location.get_sort_name ().contains (search)) {
                    bool selected = world.location_exists (location);
                    locations.append (new ClockLocation (location, selected));
                }
                return;
            default:
                break;
        }

        var loc = location.next_child (null);
        while (loc != null) {
            query_locations (loc, search);
            if (locations.get_n_items () >= RESULT_COUNT_LIMIT) {
                return;
            }
            loc = location.next_child (loc);
        }
    }
}

} // namespace World
} // namespace Clocks
