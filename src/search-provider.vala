/*
 * Copyright (C) 2014  Paolo Borelli <pborelli@gnome.org>
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

[DBus (name = "org.gnome.Shell.SearchProvider2")]
public class SearchProvider : Object {

    [DBus (visible = false)]
    public signal void activate (uint32 timestamp);

    private HashTable<string, World.Item> locations;

    private void load () {
        // FIXME: for now we just reread the list from settings every time a
        // search is started. This is not very efficient and it also duplicates
        // some code from World... Ideally we should just share the data
        // with the World panel, but that requires refactoring since the
        // window may have not been created yet.
        locations = new HashTable<string, World.Item> (str_hash, str_equal);;
        var settings = new GLib.Settings ("org.gnome.clocks");
        int count = 0;
        foreach (var l in settings.get_value ("world-clocks")) {
            World.Item? location = World.Item.deserialize (l);
            if (location != null) {
                locations.insert (count.to_string (), location);
            }
            count++;
        }
    }

    public string[] get_initial_result_set (string[] terms) {
        load ();

        List<string> normalized_terms = new List<string> ();
        foreach (string t in terms) {
            normalized_terms.prepend (t.normalize ().casefold ());
        }

        var result = new GenericArray<string> ();
        locations.foreach ((id, item) => {
            if (item.matches_search (normalized_terms)) {
                result.add (id);
            }
        });

        return result.data;
    }

    public string[] get_subsearch_result_set (string[] previous_results, string[] terms) {
        List<string> normalized_terms = new List<string> ();
        foreach (string t in terms) {
            normalized_terms.prepend (t.normalize ().casefold ());
        }

        var result = new GenericArray<string> ();
        foreach (var r in previous_results) {
            var item = locations.get (r);
            if (item != null && item.matches_search (normalized_terms)) {
                result.add (r);
            }
        }

        return result.data;
    }

    public HashTable<string, Variant>[] get_result_metas (string[] results) {
        var result = new GenericArray<HashTable<string, Variant>> ();
        foreach (var r in results) {
            var meta = new HashTable<string, Variant> (str_hash, str_equal);;
            var item = locations.get (r);
            if (item != null) {
                string time_label = item.time_label;
                string day =  item.day_label;
                if (day != null) {
                    time_label += " " + day;
                }
                meta.insert ("id", r);
                meta.insert ("name", time_label);
                meta.insert ("description", item.name);
            }
            result.add (meta);
        }

        return result.data;
    }

    public void activate_result (string result, string[] terms, uint32 timestamp) {
        activate (timestamp);
    }

    public void launch_search (string[] terms, uint32 timestamp) {
    }
}

} // namespace Clocks
