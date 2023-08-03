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

    private GWeather.Location _world;
    private GWeather.Search _search;

    [DBus (visible = false)]
    public signal void activate (uint32 timestamp);

    construct {
        _search = GWeather.Search.get_world ();
        _world = GWeather.Location.get_world ();
    }

    private string[] normalize_terms (string[] terms) {
        var normalized_terms = new GenericArray<string> ();
        foreach (string t in terms) {
            normalized_terms.add (t.normalize ().casefold ());
        }

        return normalized_terms.data;
    }

    private bool location_matches (GWeather.Location location, string[] normalized_terms) {
        var city = location.get_city_name ();
        var country = location.get_country_name ();

        if (city == null || country == null) {
            return false;
        }

        foreach (string t in normalized_terms) {
            if (!((string) city).normalize ().casefold ().contains (t) &&
                !((string) country).normalize ().casefold ().contains (t)) {
                return false;
            }
        }

        return true;
    }

    private string serialize_location (GWeather.Location location) {
        return location.serialize ().print (false);
    }

    private GWeather.Location? deserialize_location (string str) {
        Variant variant;

        try {
            variant = Variant.parse (new VariantType ("(uv)"), str, null, null);
        } catch (GLib.VariantParseError e) {
            warning ("Malformed variant: %s", e.message);
            return null;
        }

        if (_world != null) {
            return _world.deserialize (variant);
        } else {
            return null;
        }
    }

    private async string[] search_locations (string[] normalized_terms) {
        var matches = _search.find_matching (normalized_terms);
        var n_items = matches.get_n_items ();
        string[] result = {};

        for (var i = 0; i < n_items; i++) {
            var location = (GWeather.Location)matches.get_item (i);

            if (location.get_level () < GWeather.LocationLevel.CITY)
                continue;

            // FIXME: Avoid cities without children locations
            if (location.get_level () == GWeather.LocationLevel.CITY &&
                location.next_child (null) == null) {
                continue;
            }

            // HACK: the search provider interface does not currently allow variants as result IDs
            result += serialize_location (location);
        }

        return result;
    }

    public async string[] get_initial_result_set (string[] terms) throws GLib.DBusError, GLib.IOError {
        keep_alive ();

        return yield search_locations (normalize_terms (terms));
    }

    public async string[] get_subsearch_result_set (string[] previous_results, string[] terms) throws GLib.DBusError, GLib.IOError {
        keep_alive ();

        return yield search_locations (normalize_terms (terms));
    }

    public HashTable<string, Variant>[] get_result_metas (string[] results) throws GLib.DBusError, GLib.IOError {
        var result = new GenericArray<HashTable<string, Variant>> ();
        int count = 0;

        foreach (var str in results) {
            var location = deserialize_location (str);

            if (location == null) {
                continue;
            }

            var meta = new HashTable<string, Variant> (str_hash, str_equal);
            var item = new World.Item ((GWeather.Location) location);
            var time_label = item.time_label;
            var day = item.day_label;
            if (day != null) {
                time_label += " " + (string) day;
            }
            count++;
            meta.insert ("id", count.to_string ());
            meta.insert ("name", time_label);
            meta.insert ("description", (string) item.name);

            result.add (meta);
        }

        return result.data;
    }

    public void activate_result (string result, string[] terms, uint32 timestamp) throws GLib.DBusError, GLib.IOError {
        activate (timestamp);
    }

    public void launch_search (string[] terms, uint32 timestamp) throws GLib.DBusError, GLib.IOError {
    }

    private void keep_alive () {
        var app = (Clocks.Application)GLib.Application.get_default ();
        app.hold ();
        GLib.Timeout.add_seconds(10, () => {
            app.release ();
            return false;
        });
    }
}

} // namespace Clocks
