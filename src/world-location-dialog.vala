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
private class LocationDialog : Gtk.Dialog {
    [GtkChild]
    private Gtk.Stack stack;
    [GtkChild]
    private Gtk.Box empty_search_box;
    [GtkChild]
    private Gtk.SearchEntry location_entry;
    [GtkChild]
    private Gtk.ListBox listbox;
    private Face world;
    private ListStore locations;

    private const int RESULT_COUNT_LIMIT = 12;

    public LocationDialog (Gtk.Window parent, Face world_face) {
        Object (transient_for: parent, use_header_bar: 1);

        key_press_event.connect ((event) => {
            if (event.keyval == Gdk.Key.Tab)
                return Gdk.EVENT_PROPAGATE;
            return location_entry.handle_event (event);
        });

        world = world_face;

        locations = new ListStore (typeof (ClockLocation));
        listbox.bind_model (locations, (data) => {
            var row = new AddClockRow ((ClockLocation) data);
            row.added.connect ((location) => world.add_location (location));
            row.deleted.connect ((location) => world.remove_location (location));
            return row;
        });
    }

    [GtkCallback]
    private void on_search_changed () {
        // Remove old results
        locations.remove_all ();

        if (location_entry.text == "") {
            stack.visible_child = empty_search_box;
            return;
        }

        string search = location_entry.text.normalize ().casefold ();
        var world_location = GWeather.Location.get_world ();
        if (world_location == null) {
            return;
        }

        query_locations ((GWeather.Location) world_location, search);

        if (locations.get_n_items () == 0) {
            stack.visible_child = empty_search_box;
            return;
        }
        locations.sort ((a, b) => {
            var name_a = ((ClockLocation) a).location.get_sort_name ();
            var name_b = ((ClockLocation) b).location.get_sort_name ();
            return strcmp (name_a, name_b);
        });

        stack.visible_child = listbox;
    }

    private void query_locations (GWeather.Location location, string search) {
        if (locations.get_n_items () >= RESULT_COUNT_LIMIT) return;

        if (location.get_level () == GWeather.LocationLevel.CITY) {
            var contains_name = location.get_sort_name ().contains (search);

            var country_name = location.get_country_name ();
            if (country_name != null) {
                country_name = ((string) country_name).normalize ().casefold ();
            }
            var contains_country_name = country_name != null && ((string) country_name).contains (search);

            string? timezone_name = null;
            var timezone = location.get_timezone ();
            if (timezone != null) {
                timezone_name = ((GWeather.Timezone) timezone).get_name ();
                if (timezone_name != null) {
                    timezone_name = ((string) timezone_name).normalize ().casefold ();
                }
            }
            var contains_timezone_name = timezone_name != null && ((string) timezone_name).contains (search);

            if (contains_name || contains_country_name || contains_timezone_name) {
                bool selected = world.location_exists (location);
                locations.append (new ClockLocation (location, selected));
            }
            return;
        }
        foreach (var child in location.get_children ()) {
            query_locations (child, search);
            if (locations.get_n_items () >= RESULT_COUNT_LIMIT) {
                return;
            }
        }
    }
}

} // namespace World
} // namespace Clocks
