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

[GtkTemplate (ui = "/org/gnome/clocks/ui/window.ui")]
public class Window : Adw.ApplicationWindow {
    private const GLib.ActionEntry[] ACTION_ENTRIES = {
        { "new", on_new_activate },
        { "help", on_help_activate },
        { "navigate-forward", on_navigate_forward },
        { "navigate-backward", on_navigate_backward },
        { "about", on_about_activate },
    };

    [GtkChild]
    private unowned HeaderBar header_bar;
    [GtkChild]
    private unowned Adw.ToastOverlay toast_overlay;
    [GtkChild]
    private unowned Adw.NavigationView navigation_view;
    [GtkChild]
    private unowned Adw.NavigationPage main_page;
    [GtkChild]
    private unowned Adw.NavigationPage world_subpage;
    [GtkChild]
    private unowned Adw.NavigationPage alarm_subpage;
    [GtkChild]
    private unowned Adw.ViewStack stack;
    [GtkChild]
    private unowned World.Face world;
    [GtkChild]
    private unowned Alarm.Face alarm;
    [GtkChild]
    private unowned World.Standalone world_standalone;
    [GtkChild]
    private unowned Alarm.RingingPanel alarm_ringing_panel;
    [GtkChild]
    private unowned Stopwatch.Face stopwatch;
    [GtkChild]
    private unowned Timer.Face timer;

    private GLib.Settings settings;

    // DIY DzlBindingGroup
    private Binding? bind_button_mode = null;
    private Binding? bind_new_label = null;

    private bool inited = false;

    construct {
        install_action ("set-page", "s", (Gtk.WidgetActionActivateFunc) on_set_page);

        add_binding_action (Gdk.Key.@1,
                            Gdk.ModifierType.ALT_MASK,
                            "set-page", "s", "world");
        add_binding_action (Gdk.Key.@2,
                            Gdk.ModifierType.ALT_MASK,
                            "set-page", "s", "alarm");
        add_binding_action (Gdk.Key.@3,
                            Gdk.ModifierType.ALT_MASK,
                            "set-page", "s", "stopwatch");
        add_binding_action (Gdk.Key.@4,
                            Gdk.ModifierType.ALT_MASK,
                            "set-page", "s", "timer");
    }

    public Window (Application app) {
        Object (application: app);

        add_action_entries (ACTION_ENTRIES, this);

        settings = new Settings ("org.gnome.clocks.state.window");
        settings.delay ();

        // GSettings gives us the nick, which matches the stack page name
        stack.visible_child_name = settings.get_string ("panel-id");

        inited = true;

        pane_changed ();

        load_window_state ();

        world.show_standalone.connect ((w, l) => {
            stack.visible_child = w;
            world_standalone.location = l;
            Utils.WallClock.get_default ().seconds_precision = true;
            navigation_view.push (world_subpage);
        });
        world_subpage.hidden.connect (() => {
            Utils.WallClock.get_default ().seconds_precision = false;
        });

        alarm.ring.connect ((w, a) => {
            close_standalone ();
            stack.visible_child = w;
            alarm_ringing_panel.alarm = a;
            navigation_view.push (alarm_subpage);
        });

        // Immediately check if we need to notify the user about alarms
        Utils.WallClock.get_default ().tick ();

        stopwatch.notify["state"].connect ((w) => {
            var stopwatch_stack_page = stack.get_page (stopwatch);
            stopwatch_stack_page.needs_attention = (stopwatch.state == Stopwatch.Face.State.RUNNING);
        });

        timer.ring.connect ((w) => {
            close_standalone ();
            stack.visible_child = w;
        });


        timer.notify["is-running"].connect ((w) => {
            var timer_stack_page = stack.get_page (timer);
            timer_stack_page.needs_attention = timer.is_running;
        });

        if (Config.PROFILE == "Devel") {
            add_css_class ("devel");
        }
    }

    private void on_new_activate () {
        ((Clock) stack.visible_child).activate_new ();
    }

    public void show_world () {
        close_standalone ();
        stack.visible_child = world;
    }

    public void add_world_location (GWeather.Location location) {
        world.add_location (location);
    }

    public override bool close_request () {
        save_window_state ();
        return base.close_request ();
    }

    private void load_window_state () {
        var window_maximized = settings.get_boolean ("maximized");
        if (window_maximized) {
            maximize ();
        } else {
            int width, height;
            settings.get ("size", "(ii)", out width, out height);
            set_default_size (width, height);
        }
    }

    private void save_window_state () {
        var width = 0;
        var height = 0;

        get_default_size (out width, out height);

        debug ("Saving window geometry: %i × %i", width, height);

        settings.set ("size", "(ii)", width, height);

        settings.set_boolean ("maximized", is_maximized ());
        settings.apply ();
    }

    [GtkCallback]
    private void on_window_active () {
        if (is_active) {
            ((Application) application).withdraw_notifications ();
        }
    }

    [GtkCallback]
    private bool key_press_cb (Gtk.EventControllerKey controller, uint keyval, uint keycode, Gdk.ModifierType mod_state) {
        bool handled = false;
        var state = mod_state & (Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.ALT_MASK);

        if (keyval == Gdk.Key.Escape && state == 0) {
            if (navigation_view.visible_page == main_page) {
                handled = ((Clock) stack.visible_child).escape_pressed ();
            } else {
                navigation_view.pop ();
            }
        }

        return handled;
    }

    private void on_help_activate () {
        Gdk.Display display;
        GLib.AppLaunchContext context;

        display = get_display ();
        if (display != null)
            context = display.get_app_launch_context ();
        else
            context = null;

        GLib.AppInfo.launch_default_for_uri_async.begin ("help:gnome-clocks", context, null, (obj, res) => {
            try {
                GLib.AppInfo.launch_default_for_uri_async.end (res);
            } catch (Error error) {
                warning ("Could not open help: %s", error.message);
            }
        });
    }

    private void on_about_activate () {
        const string COPYRIGHT = "\xc2\xa9 2011 Collabora Ltd.\n" +
                                 "\xc2\xa9 2012-2013 Collabora Ltd., Seif Lotfy, Emily Gonyer, " +
                                 "Eslam Mostafa, Paolo Borelli, Volker Sobek\n" +
                                 "\xc2\xa9 2019-2020 Bilal Elmoussaoui &amp; Zander Brown et al";

        const string? DEVELOPERS[] = {
            "Alex Anthony",
            "Paolo Borelli",
            "Allan Day",
            "Piotr Drąg",
            "Emily Gonyer",
            "Evgeny Bobkin",
            "Maël Lavault",
            "Seif Lotfy",
            "William Jon McCann",
            "Eslam Mostafa",
            "Bastien Nocera",
            "Volker Sobek",
            "Jakub Steiner",
            "Bilal Elmoussaoui",
            "Zander Brown",
            null
        };

        var about = new Adw.AboutDialog () {
            application_name = _("Clocks"),
            application_icon = Config.APP_ID,
            developer_name = _("The GNOME Project"),
            version = Config.VERSION,
            copyright = COPYRIGHT,
            developers = DEVELOPERS,
            issue_url = "https://gitlab.gnome.org/GNOME/gnome-clocks/-/issues/",
            license_type = Gtk.License.GPL_2_0,
            translator_credits = _("translator-credits")
        };

        about.present (this);
    }

    [GtkCallback]
    private void pane_changed () {
        var panel = (Clock) stack.visible_child;

        if (stack.in_destruction ()) {
            return;
        }

        if (inited) {
            settings.set_enum ("panel-id", panel.panel_id);
        }

        if (bind_button_mode != null) {
            ((Binding) bind_button_mode).unbind ();
        }
        bind_button_mode = panel.bind_property ("button-mode",
                                                header_bar,
                                                "button-mode",
                                                SYNC_CREATE);

        if (bind_new_label != null) {
            ((Binding) bind_new_label).unbind ();
        }
        bind_new_label = panel.bind_property ("new-label",
                                              header_bar,
                                              "new-label",
                                              SYNC_CREATE);

        stack.visible_child.grab_focus ();
    }

    [GtkCallback]
    private void visible_page_changed () {
        if (navigation_view.visible_page == alarm_subpage) {
            title = _("Alarm");
        } else if (navigation_view.visible_page == world_subpage) {
            title = world_standalone.title;
        } else {
            title = _("Clocks");
        }

        deletable = (navigation_view.visible_page != alarm_subpage);
    }

    [GtkCallback]
    private void alarm_dismissed () {
        navigation_view.pop ();
    }

    private void close_standalone () {
        navigation_view.pop ();
    }

    private void on_navigate_forward () {
        var current = stack.visible_child_name;
        switch (current) {
        case "world":
            stack.visible_child_name = "alarm";
            break;
        case "alarm":
            stack.visible_child_name = "stopwatch";
            break;
        case "stopwatch":
            stack.visible_child_name = "timer";
            break;
        case "timer":
            stack.visible_child_name = "world";
            break;
        }
    }

    private void on_navigate_backward () {
        var current = stack.visible_child_name;
        switch (current) {
        case "world":
            stack.visible_child_name = "timer";
            break;
        case "alarm":
            stack.visible_child_name = "world";
            break;
        case "stopwatch":
            stack.visible_child_name = "alarm";
            break;
        case "timer":
            stack.visible_child_name = "stopwatch";
            break;
        }
    }

    private void on_set_page (string action_name, Variant? param) {
        if (param != null) {
            var page = param.get_string ();
            stack.visible_child_name = page;
        }
    }

    public void add_toast (Adw.Toast toast) {
        toast_overlay.add_toast (toast);
    }
}

} // namespace Clocks
