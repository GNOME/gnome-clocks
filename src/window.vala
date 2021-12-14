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
        // primary menu
        { "show-primary-menu", on_show_primary_menu_activate, null, "false", null },
        { "new", on_new_activate },
        { "back", on_back_activate },
        { "help", on_help_activate },
        { "about", on_about_activate },
    };

    [GtkChild]
    private unowned HeaderBar header_bar;
    [GtkChild]
    private unowned Adw.Leaflet alarm_leaflet;
    [GtkChild]
    private unowned Adw.Leaflet world_leaflet;
    [GtkChild]
    private unowned Gtk.Box main_view;
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
        // plain ctrl+page_up/down is easten by the scrolled window...
        add_binding_action (Gdk.Key.Page_Up,
                            Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.ALT_MASK,
                            "change-page", "(i)", 0);

        add_binding_action (Gdk.Key.Page_Down,
                            Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.ALT_MASK,
                            "change-page", "(i)", 1);

        add_binding_action (Gdk.Key.@1,
                            Gdk.ModifierType.ALT_MASK,
                            "set-page", "(s)", "world");
        add_binding_action (Gdk.Key.@2,
                            Gdk.ModifierType.ALT_MASK,
                            "set-page", "(s)", "alarm");
        add_binding_action (Gdk.Key.@3,
                            Gdk.ModifierType.ALT_MASK,
                            "set-page", "(s)", "stopwatch");
        add_binding_action (Gdk.Key.@4,
                            Gdk.ModifierType.ALT_MASK,
                            "set-page", "(s)", "timer");
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
            world_leaflet.navigate (Adw.NavigationDirection.FORWARD);
        });

        alarm.ring.connect ((w, a) => {
            close_standalone ();
            stack.visible_child = w;
            alarm_ringing_panel.alarm = a;
            alarm_leaflet.visible_child = alarm_ringing_panel;
        });

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

        this.hide_on_close = true;
    }

    [Signal (action = true)]
    public virtual signal void change_page (int offset) {
        var dir = false;

        if (get_direction () == RTL) {
            dir = offset == 0 ? false : true;
        } else {
            dir = offset == 1 ? false : true;
        }

        switch (stack.visible_child_name) {
            case "world":
                if (dir) {
                    stack.error_bell ();
                } else {
                    stack.visible_child = alarm;
                }
                break;
            case "alarm":
                if (dir) {
                    stack.visible_child = world;
                } else {
                    stack.visible_child = stopwatch;
                }
                break;
            case "stopwatch":
                if (dir) {
                    stack.visible_child = alarm;
                } else {
                    stack.visible_child = timer;
                }
                break;
            case "timer":
                if (dir) {
                    stack.visible_child = stopwatch;
                } else {
                    stack.error_bell ();
                }
                break;
        }
    }

    [Signal (action = true)]
    public virtual signal void set_page (string page) {
        stack.visible_child_name = page;
    }

    private void on_show_primary_menu_activate (SimpleAction action) {
        var state = ((!) action.get_state ()).get_boolean ();
        action.set_state (new Variant.boolean (!state));
    }

    private void on_new_activate () {
        ((Clock) stack.visible_child).activate_new ();
    }

    private void on_back_activate () {
        world_leaflet.navigate (Adw.NavigationDirection.BACK);
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
            width = settings.get_int ("width");
            height = settings.get_int ("height");
            set_default_size (width, height);
        }
    }

    private void save_window_state () {
        var width = 0;
        var height = 0;

        get_default_size (out width, out height);

        debug ("Saving window geometry: %i × %i", width, height);

        settings.set_int ("width", width);
        settings.set_int ("height", height);

        settings.set_boolean ("maximized", is_maximized ());
        settings.apply ();
    }

    [GtkCallback]
    private void enter_cb (Gtk.EventControllerFocus controller) {
        ((Application) application).withdraw_notifications ();
    }

    [GtkCallback]
    private bool key_press_cb (Gtk.EventControllerKey controller, uint keyval, uint keycode, Gdk.ModifierType mod_state) {
        bool handled = false;
        var state = mod_state & (Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.ALT_MASK);

        if (keyval == Gdk.Key.Escape && state == 0) {
            if (world_leaflet.visible_child == main_view) {
                handled = ((Clock) stack.visible_child).escape_pressed ();
            } else {
                world_leaflet.navigate (Adw.NavigationDirection.BACK);
            }
        }

        return handled;
    }

    private void on_help_activate () {
        Gtk.show_uri (this, "help:gnome-clocks", Gdk.CURRENT_TIME);
    }

    private void on_about_activate () {
        const string COPYRIGHT = "Copyright \xc2\xa9 2011 Collabora Ltd.\n" +
                                 "Copyright \xc2\xa9 2012-2013 Collabora Ltd., Seif Lotfy, Emily Gonyer\n" +
                                 "Eslam Mostafa, Paolo Borelli, Volker Sobek\n" +
                                 "Copyright \xc2\xa9 2019-2020 Bilal Elmoussaoui & Zander Brown et al";

        const string? AUTHORS[] = {
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

        var program_name = Config.NAME_PREFIX + _("Clocks");
        Gtk.show_about_dialog (this,
                               "program-name", program_name,
                               "logo-icon-name", Config.APP_ID,
                               "version", Config.VERSION,
                               "comments", _("Utilities to help you with the time."),
                               "copyright", COPYRIGHT,
                               "authors", AUTHORS,
                               "license-type", Gtk.License.GPL_2_0,
                               "wrap-license", false,
                               "translator-credits", _("translator-credits"),
                               null);
    }

    [GtkCallback]
    private void pane_changed () {
        var help_overlay = get_help_overlay ();
        var panel = (Clock) stack.visible_child;

        if (stack.in_destruction ()) {
            return;
        }

        ((Gtk.ShortcutsWindow) help_overlay).view_name = Type.from_instance (panel).name ();

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
    private void visible_child_changed () {
        if (alarm_leaflet.visible_child == alarm_ringing_panel) {
            title = _("Alarm");
        } else if (world_leaflet.visible_child == world_standalone) {
            title = world_standalone.title;
        } else {
            title = _("Clocks");
        }

        deletable = (alarm_leaflet.visible_child != alarm_ringing_panel);
    }

    [GtkCallback]
    private void alarm_dismissed () {
        alarm_leaflet.visible_child = world_leaflet;
    }

    private void close_standalone () {
        world_leaflet.visible_child = main_view;
    }
}

} // namespace Clocks
