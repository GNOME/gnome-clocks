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

private class NewWorldClock : Object {
    public GWeather.Location location { get; construct set; }
    public bool added { get; set; }

    public NewWorldClock (GWeather.Location location, bool added) {
        this.location = location;
        this.added = added;
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

        world = world_face;

        locations = new ListStore (typeof (NewWorldClock));
        listbox.bind_model (locations, (data) => {
            var row = new AddClockRow ((NewWorldClock) data);
            row.added.connect ((location) => world.add_location (location));
            row.deleted.connect ((location) => world.remove_location (location));
            return row;
        });
    }

    [GtkCallback]
    private void on_search_changed () {
        // Remove old results
        locations.remove_all ();

        if (location_entry.get_text () == "") {
            stack.visible_child = empty_search_box;
            return;
        }

        string search = location_entry.get_text ().normalize ().casefold ();
        List<GWeather.Location> results = new List<GWeather.Location> ();
        var world_location = GWeather.Location.get_world ();
        if (world_location == null) {
            return;
        }

        query_locations ((GWeather.Location) world_location, ref results, search);
        results.sort ((a, b) => {
            return strcmp (a.get_sort_name (), b.get_sort_name ());
        });

        if (results.length () == 0) {
            stack.visible_child = empty_search_box;
            return;
        }
        stack.visible_child = listbox;

        // Add new results
        foreach (var city in results) {
            bool added = world.location_exists (city);
            locations.append (new NewWorldClock (city, added));
        }
    }

    private void query_locations (GWeather.Location location, ref List<GWeather.Location> output, string search) {
        if (output.length () >= RESULT_COUNT_LIMIT) return;

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
