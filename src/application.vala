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

public class Application : Adw.Application {
    const OptionEntry[] OPTION_ENTRIES = {
        { "version", 'v', 0, OptionArg.NONE, null, N_("Print version information and exit"), null },
        { (string) null }
    };

    const GLib.ActionEntry[] ACTION_ENTRIES = {
        { "stop-alarm", null, "s" },
        { "snooze-alarm", null, "s" },
        { "quit", on_quit_activate },
        { "add-location", on_add_location_activate, "v" }
    };

    private SearchProvider search_provider;
    private uint search_provider_id = 0;
    private World.ShellWorldClocks world_clocks;
    private uint world_clocks_id = 0;
    private Window? window;
    private List<string> system_notifications;

    private Window ensure_window () ensures (window != null) {
        if (window == null) {
            window = new Window (this);
        }
        return (Window) window;
    }

    public Application () {
        Object (application_id: Config.APP_ID,
                resource_base_path: "/org/gnome/clocks/");

        Gtk.Window.set_default_icon_name (Config.APP_ID);

        add_main_option_entries (OPTION_ENTRIES);
        add_action_entries (ACTION_ENTRIES, this);

        search_provider = new SearchProvider ();
        search_provider.activate.connect ((timestamp) => {
            var win = ensure_window ();
            win.show_world ();
            win.present ();
        });

        system_notifications = new List<string> ();
    }

    public override bool dbus_register (DBusConnection connection, string object_path) {
        try {
            search_provider_id = connection.register_object (object_path + "/SearchProvider", search_provider);
        } catch (IOError error) {
            printerr ("Could not register search provider service: %s\n", error.message);
        }

        try {
            world_clocks = new World.ShellWorldClocks (connection, object_path);
            world_clocks_id = connection.register_object (object_path, world_clocks);
        } catch (IOError error) {
            printerr ("Could not register world clocks service: %s\n", error.message);
        }

        return true;
    }

    public override void dbus_unregister (DBusConnection connection, string object_path) {
        if (search_provider_id != 0) {
            connection.unregister_object (search_provider_id);
            search_provider_id = 0;
        }

        if (world_clocks_id != 0) {
            connection.unregister_object (world_clocks_id);
            world_clocks_id = 0;
        }
    }

    protected override void activate () {
        base.activate ();

        var win = ensure_window ();
        win.present ();
    }

    protected override void startup () {
        base.startup ();

        if ((get_flags () & ApplicationFlags.IS_SERVICE) != 0)
            set_inactivity_timeout (10000);

        set_accels_for_action ("win.new", { "<Control>n" });
        set_accels_for_action ("win.help", { "F1" });
        set_accels_for_action ("window.close", { "<Control>w" });
        set_accels_for_action ("app.quit", { "<Control>q" });
        set_accels_for_action ("win.navigate-backward", { "<Control><Alt>Page_Up" });
        set_accels_for_action ("win.navigate-forward", { "<Control><Alt>Page_Down" });
    }

    protected override int handle_local_options (GLib.VariantDict options) {
        if (options.contains ("version")) {
            print ("%s %s\n", (string) Environment.get_application_name (), Config.VERSION);
            return 0;
        }

        return -1;
    }

    public void on_add_location_activate (GLib.SimpleAction action, GLib.Variant? parameter) {
        if (parameter == null) {
            return;
        }

        var win = ensure_window ();
        win.show_world ();
        win.present ();

        var world = GWeather.Location.get_world ();
        if (world != null) {
            // The result is actually nullable
            var location = (GWeather.Location?) ((GWeather.Location) world).deserialize ((Variant) parameter);
            if (location != null) {
                win.add_world_location ((GWeather.Location) location);
            }
        } else {
            warning ("the world is missing");
        }
    }

    public new void send_notification (string notification_id, GLib.Notification notification) {
        base.send_notification (notification_id, notification);

        if (system_notifications.find (notification_id) == null) {
            system_notifications.append (notification_id);
        }
    }

    public void withdraw_notifications () {
        foreach (var notification in system_notifications) {
            withdraw_notification (notification);
        }

        system_notifications = new List<string> ();
    }

    public override void shutdown () {
        base.shutdown ();

        withdraw_notifications ();
    }

    void on_quit_activate () {
        if (window != null) {
            ((Window) window).close ();
        }
        quit ();
    }
}

} // namespace Clocks
