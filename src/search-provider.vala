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

        var world = GWeather.Location.get_world ();
        if (world != null) {
            return ((GWeather.Location) world).deserialize (variant);
        } else {
            return null;
        }
    }

    private void search_locations_recurse (GWeather.Location location, string[] normalized_terms,
                                           GenericArray<GWeather.Location> matches) {
        var loc = location.next_child (null);
        while (loc != null) {
            var level = loc.get_level ();
            if (level == CITY || level == NAMED_TIMEZONE) {
                if (location_matches (loc, normalized_terms)) {
                    matches.add (loc);
                }
            }

            search_locations_recurse (loc, normalized_terms, matches);
            loc = location.next_child (loc);
        }
    }

    private async string[] search_locations (string[] normalized_terms) {
        var world = GWeather.Location.get_world ();
        var matches = new GenericArray<GWeather.Location> ();

        if (world == null) {
            return {};
        }

        search_locations_recurse ((GWeather.Location) world, normalized_terms, matches);

        string[] result = {};
        matches.foreach ((location) => {
            // FIXME: Avoid cities without children locations
            if (location.get_level () == GWeather.LocationLevel.CITY &&
                location.next_child (null) == null) {
                return;
            }
            // HACK: the search provider interface does not currently allow variants as result IDs
            result += serialize_location (location);
        });

        return result;
    }

    public async string[] get_initial_result_set (string[] terms) throws GLib.DBusError, GLib.IOError {
        renew_inactivity_timeout ();

        return yield search_locations (normalize_terms (terms));
    }

    public async string[] get_subsearch_result_set (string[] previous_results, string[] terms) throws GLib.DBusError, GLib.IOError {
        renew_inactivity_timeout ();

        var normalized_terms = normalize_terms (terms);

        if (previous_results.length == 0) {
            return yield search_locations (normalized_terms);
        }

        string[] result = {};
        foreach (var str in previous_results) {
            var location = deserialize_location (str);

            if (location != null &&
                location_matches ((GWeather.Location) location, normalized_terms)) {
                result += (str);
            }
        }

        return result;
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

    private void renew_inactivity_timeout () {
        var app = GLib.Application.get_default ();

        app.hold ();
        app.release ();
    }
}

} // namespace Clocks
