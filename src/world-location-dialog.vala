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

private class AddClockRowData : Object {
    public GWeather.Location location;

    public AddClockRowData (GWeather.Location location) {
        this.location = location;
    }
}

[GtkTemplate (ui = "/org/gnome/clocks/ui/world-location-dialog.ui")]
private class LocationDialog : Gtk.Dialog {
    [GtkChild]
    private Gtk.Stack stack;
    [GtkChild]
    private Gtk.Box empty_search_box;
    [GtkChild]
    private Gtk.Widget no_results_label;
    [GtkChild]
    private Gtk.ScrolledWindow list_view;
    [GtkChild]
    private Gtk.SearchEntry location_entry;
    [GtkChild]
    private Gtk.ListBox listbox;
    private Face world;
    private ListStore locations;

    private const int RESULT_COUNT_LIMIT = 6;

    public LocationDialog (Gtk.Window parent, Face world_face) {
        Object (transient_for: parent, use_header_bar: 1);

        world = world_face;

        locations = new ListStore (typeof (AddClockRowData));
        listbox.bind_model (locations, (data) => {
            var row = new AddClockRow (((AddClockRowData)data).location, world);
            row.added.connect ((location)=>{
               world.add_location (location);
            });
            row.deleted.connect ((location)=>{
               world.remove_location (location);
            });
            return row;
        });
    }

    [GtkCallback]
    private void icon_released () {
        if (location_entry.secondary_icon_name == "edit-clear-symbolic") {
            location_entry.set_text ("");
        }
    }

    [GtkCallback]
    private async void on_search_changed () {
        if (location_entry.get_text () == "") {
            stack.visible_child = empty_search_box;
            return;
        }

        string search = location_entry.get_text ().casefold ();
        SourceFunc callback = on_search_changed.callback;
        List<GWeather.Location> results = new List<GWeather.Location> ();
        ThreadFunc<bool> run = () => {
            var world = GWeather.Location.get_world ();
            if (world == null) {
                return true;
            }

            query_locations ((GWeather.Location)world, ref results, search);
            results.sort ((a, b)=>{
                return strcmp (a.get_sort_name (), b.get_sort_name ());
            });
            // Pass back result and schedule callback
            Idle.add ((owned) callback);
            return true;
        };
        new Thread<bool> ("search-thread", (owned)run);

        // Wait for search results
        yield;

        if (results.length () == 0) {
            stack.set_visible_child (no_results_label);
            return;
        }
        stack.set_visible_child (list_view);

        // Remove old results
        locations.remove_all ();
        // Add new results
        foreach (var city in results) {
            locations.append (new AddClockRowData (city));
        }
    }

    private void query_locations (GWeather.Location location, ref List<GWeather.Location> output, string search) {
        if (output.length () >= RESULT_COUNT_LIMIT) return;

        if (location.get_level () == GWeather.LocationLevel.CITY) {
            if (location.get_name ().casefold ().contains (search)) {
                output.append (location);
            }
            return;
        }
        foreach (var child in location.get_children ()) {
            query_locations (child, ref output, search);
            if (output.length () >= RESULT_COUNT_LIMIT) return;
        }
    }
}

} // namespace World
} // namespace Clocks
