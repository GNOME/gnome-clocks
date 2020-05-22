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

// Export world clock locations to GNOME Shell
[DBus (name = "org.gnome.Shell.ClocksIntegration")]
public class ShellWorldClocks : Object {
    [DBus (signature = "av")]
    public Variant locations {
        owned get {
            Variant dict;
            Variant[] rv = {};
            var locations = settings.get_value ("world-clocks");
            var iter = locations.iterator ();

            while (iter.next ("@a{sv}", out dict)) {
                string key;
                Variant val;
                var dict_iter = dict.iterator ();
                while (dict_iter.next ("{sv}", out key, out val)) {
                    if (key == "location") {
                        rv += val;
                    }
                }
            }

            return rv;
        }
    }

    private DBusConnection connection;
    private string object_path;

    private GLib.Settings settings;

    public ShellWorldClocks (DBusConnection connection, string object_path) {
        this.connection = connection;
        this.object_path = object_path;

        settings = new GLib.Settings ("org.gnome.clocks");
        settings.changed["world-clocks"].connect (() => {
            var builder = new VariantBuilder (VariantType.ARRAY);
            var invalid_builder = new VariantBuilder (new VariantType ("as"));

            Variant v = locations;
            builder.add ("{sv}", "Locations", v);

            try {
                this.connection.emit_signal (null,
                                            this.object_path,
                                            "org.freedesktop.DBus.Properties",
                                            "PropertiesChanged",
                                            new Variant ("(sa{sv}as)",
                                                        "org.gnome.Shell.ClocksIntegration",
                                                        builder,
                                                        invalid_builder));
            } catch (Error e) {
                warning ("Shell Integration failed: %s", e.message);
            }
        });
    }
}

} // namespace World
} // namespace Clocks
