/*
 * Copyright (C) 2018  Canonical Ltd
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

/* Trivial program to activate the named alarm or set up all alarms as part of
 * initial login. To be executed by our systemd unit. */

[DBus (name="org.freedesktop.Application")]
interface Application : Object {
    public abstract void activate_action (string action_name,
                                          Variant[] params,
                                          GLib.HashTable<string, Variant> platform_data)
        throws IOError;
}

int main (string[] args) {
    Intl.bindtextdomain (Config.GETTEXT_PACKAGE, Config.GNOMELOCALEDIR);
    Intl.bind_textdomain_codeset (Config.GETTEXT_PACKAGE, "UTF-8");
    Intl.textdomain (Config.GETTEXT_PACKAGE);

    if (args.length != 2) {
        stderr.printf ("Usage: %s [alarm id|all]\n", args[0]);
        return Posix.EXIT_FAILURE;
    }

    try {
        Application proxy = Bus.get_proxy_sync (GLib.BusType.SESSION,
                                                "org.gnome.clocks",
                                                "/org/gnome/clocks");

        /* no platform_data */
        GLib.HashTable<string,Variant> empty = new GLib.HashTable<string, Variant> (null, null);
        if (args[1] == "all") {
            proxy.activate_action ("activate-all-alarms", {}, empty);
        } else {
            proxy.activate_action ("activate-alarm", {args[1]}, empty);
        }
    } catch (IOError e) {
        GLib.critical ("Failed to activate alarm: %s", e.message);
        return Posix.EXIT_FAILURE;
    }

    return Posix.EXIT_SUCCESS;
}
