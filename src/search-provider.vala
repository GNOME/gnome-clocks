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

    private HashTable<string, GWeather.Location> matches;
    private int count; // Used to make up id strings

    private string[] normalize_terms (string[] terms) {
        var normalized_terms = new GenericArray<string> ();
        foreach (string t in terms) {
            normalized_terms.add (t.normalize ().casefold ());
        }

        return normalized_terms.data;
    }

    private bool location_matches (GWeather.Location location, string[] normalized_terms) {
        string city = location.get_city_name ();
        string country = Utils.get_country_name (location);
        if (city == null || country == null) {
            return false;
        }

        foreach (string t in normalized_terms) {
            if (!city.normalize ().casefold ().contains (t) &&
                !country.normalize ().casefold ().contains (t)) {
                return false;
            }
        }

        return true;
    }

    private async void search_locations (GWeather.Location location, string[] normalized_terms) {
        GWeather.Location? []locations = location.get_children ();
        if (locations != null) {
            for (int i = 0; i < locations.length; i++) {
                if (locations[i].get_level () == GWeather.LocationLevel.CITY) {
                    if (location_matches(locations[i], normalized_terms)) {
                        matches.insert (count.to_string (), locations[i]);
                        count++;
                    }
                }

                yield search_locations (locations[i], normalized_terms);
            }
        }
    }

    public async string[] get_initial_result_set (string[] terms) {
        // clear the cache
        matches = new HashTable<string, GWeather.Location> (str_hash, str_equal);
        count = 0;

        yield search_locations (GWeather.Location.get_world (), normalize_terms (terms));

        var result = new GenericArray<string> ();
        matches.foreach ((id, location) => {
            result.add (id);
        });

        return result.data;
    }

    public string[] get_subsearch_result_set (string[] previous_results, string[] terms) {
        var normalized_terms = normalize_terms (terms);

        var result = new GenericArray<string> ();
        foreach (var id in previous_results) {
            var location = matches.get (id);
            if (location != null && location_matches (location, normalized_terms)) {
                result.add (id);
            }
        }

        return result.data;
    }

    public HashTable<string, Variant>[] get_result_metas (string[] results) {
        var result = new GenericArray<HashTable<string, Variant>> ();
        foreach (var id in results) {
            var meta = new HashTable<string, Variant> (str_hash, str_equal);;
            var location = matches.get (id);
            if (location != null) {
                var item = new World.Item (location);
                string time_label = item.time_label;
                string day =  item.day_label;
                if (day != null) {
                    time_label += " " + day;
                }
                meta.insert ("id", id);
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
