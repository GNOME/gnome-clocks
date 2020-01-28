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
public class Window : Gtk.ApplicationWindow {
    private const GLib.ActionEntry[] ACTION_ENTRIES = {
        // primary menu
        { "show-primary-menu", on_show_primary_menu_activate, null, "false", null },
        { "new", on_new_activate },
        { "back", on_back_activate },
        { "help", on_help_activate },
        { "about", on_about_activate },
        { "select", on_select_activate },
        { "select-cancel", on_select_cancel_activate },

        // selection menu
        { "select-all", on_select_all_activate },
        { "select-none", on_select_none_activate }
    };

    [GtkChild]
    private HeaderBar header_bar;
    [GtkChild]
    private Gtk.Stack stack;
    [GtkChild]
    private World.Face world;
    [GtkChild]
    private Alarm.Face alarm;
    [GtkChild]
    private Stopwatch.Face stopwatch;
    [GtkChild]
    private Timer.Face timer;

    private GLib.Settings settings;

    // DIY DzlBindingGroup
    private Binding bind_button_mode = null;
    private Binding bind_view_mode = null;
    private Binding bind_can_select = null;
    private Binding bind_selected = null;
    private Binding bind_title = null;
    private Binding bind_subtitle = null;
    private Binding bind_new_label = null;

    private bool inited = false;

    public Window (Application app) {
        Object (application: app);

        add_action_entries (ACTION_ENTRIES, this);

        settings = new Settings ("org.gnome.clocks.state.window");
        settings.delay ();

        destroy.connect (() => {
            settings.apply ();
        });

        // GSettings gives us the nick, which matches the stack page name
        stack.visible_child_name = settings.get_string ("panel-id");

        inited = true;

        header_bar.bind_property ("title", this, "title", SYNC_CREATE);

        pane_changed ();

        // Setup window geometry saving
        Gdk.WindowState window_state = (Gdk.WindowState)settings.get_int ("state");
        if (Gdk.WindowState.MAXIMIZED in window_state) {
            maximize ();
        }

        int width, height;
        settings.get ("size", "(ii)", out width, out height);
        resize (width, height);

        alarm.ring.connect ((w) => {
            world.reset_view ();
            stack.visible_child = w;
        });

        stopwatch.notify["state"].connect ((w) => {
            stack.child_set_property (stopwatch, "needs-attention", stopwatch.state == Stopwatch.Face.State.RUNNING);
        });

        timer.ring.connect ((w) => {
            world.reset_view ();
            stack.visible_child = w;
        });

        timer.notify["state"].connect ((w) => {
            stack.child_set_property (timer, "needs-attention", timer.state == Timer.Face.State.RUNNING);
        });

        unowned Gtk.BindingSet binding_set = Gtk.BindingSet.by_class (get_class ());

        // plain ctrl+page_up/down is easten by the scrolled window...
        Gtk.BindingEntry.add_signal (binding_set,
                                     Gdk.Key.Page_Up,
                                     Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.MOD1_MASK,
                                     "change-page", 1,
                                     typeof (int), 0);
        Gtk.BindingEntry.add_signal (binding_set,
                                     Gdk.Key.Page_Down,
                                     Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.MOD1_MASK,
                                     "change-page", 1,
                                     typeof(int), 1);

        Gtk.StyleContext style = get_style_context ();
        if (Config.PROFILE == "Devel") {
            style.add_class ("devel");
        }

        show_all ();
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

    private void on_show_primary_menu_activate (SimpleAction action) {
        var state = action.get_state ().get_boolean ();
        action.set_state (new Variant.boolean (!state));
    }

    private void on_new_activate () {
        ((Clock) stack.visible_child).activate_new ();
    }

    private void on_back_activate () {
        ((Clock) stack.visible_child).activate_back ();
    }

    private void on_select_activate () {
        ((Clock) stack.visible_child).activate_select ();
    }

    private void on_select_cancel_activate () {
        ((Clock) stack.visible_child).activate_select_cancel ();
    }

    private void on_select_all_activate () {
        ((Clock) stack.visible_child).activate_select_all ();
    }

    private void on_select_none_activate () {
        ((Clock) stack.visible_child).activate_select_none ();
    }

    public void show_world () {
        world.reset_view ();
        stack.visible_child = world;
    }

    public void add_world_location (GWeather.Location location) {
        world.add_location (location);
    }

    public override bool key_press_event (Gdk.EventKey event) {
        uint keyval;
        bool handled = false;

        if (((Gdk.Event)(event)).get_keyval (out keyval) && keyval == Gdk.Key.Escape) {
            handled = ((Clock) stack.visible_child).escape_pressed ();
        }

        if (handled) {
            return true;
        }

        return base.key_press_event (event);
    }

    public override bool button_release_event (Gdk.EventButton event) {
        const uint BUTTON_BACK = 8;
        uint button;

        if (((Gdk.Event)(event)).get_button (out button) && button == BUTTON_BACK) {
            ((Clock) stack.visible_child).activate_back ();
            return true;
        }

        return base.button_release_event (event);
    }

    protected override bool configure_event (Gdk.EventConfigure event) {
        if (get_realized () && !(Gdk.WindowState.MAXIMIZED in get_window ().get_state ())) {
            int width, height;

            get_size (out width, out height);
            settings.set ("size", "(ii)", width, height);
        }

        return base.configure_event (event);
    }

    protected override bool window_state_event (Gdk.EventWindowState event) {
        settings.set_int ("state", event.new_window_state);
        return base.window_state_event (event);
    }

    private void on_help_activate () {
        try {
            Gtk.show_uri (get_screen (), "help:gnome-clocks", Gtk.get_current_event_time ());
        } catch (Error e) {
            warning (_("Failed to show help: %s"), e.message);
        }
    }

    private void on_about_activate () {
        const string COPYRIGHT = "Copyright \xc2\xa9 2011 Collabora Ltd.\n" +
                                 "Copyright \xc2\xa9 2012-2013 Collabora Ltd., Seif Lotfy, Emily Gonyer\n" +
                                 "Eslam Mostafa, Paolo Borelli, Volker Sobek\n" +
                                 "Copyright \xc2\xa9 2019 Bilal Elmoussaoui & Zander Brown et al";

        const string AUTHORS[] = {
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

        help_overlay.view_name = Type.from_instance (panel).name ();

        if (inited) {
            settings.set_enum ("panel-id", panel.panel_id);
        }

        if (bind_button_mode != null) {
            bind_button_mode.unbind ();
        }
        bind_button_mode = panel.bind_property ("button-mode",
                                                header_bar,
                                                "button-mode",
                                                SYNC_CREATE);

        if (bind_view_mode != null) {
            bind_view_mode.unbind ();
        }
        bind_view_mode = panel.bind_property ("view-mode",
                                              header_bar,
                                              "view-mode",
                                              SYNC_CREATE);

        if (bind_can_select != null) {
            bind_can_select.unbind ();
        }
        bind_can_select = panel.bind_property ("can-select",
                                               header_bar,
                                               "can-select",
                                               SYNC_CREATE);

        if (bind_selected != null) {
            bind_selected.unbind ();
        }
        bind_selected = panel.bind_property ("n-selected",
                                             header_bar,
                                             "n-selected",
                                             SYNC_CREATE);

        if (bind_title != null) {
            bind_title.unbind ();
        }
        bind_title = panel.bind_property ("title",
                                          header_bar,
                                          "title",
                                          SYNC_CREATE);

        if (bind_subtitle != null) {
            bind_subtitle.unbind ();
        }
        bind_subtitle = panel.bind_property ("subtitle",
                                             header_bar,
                                             "subtitle",
                                             SYNC_CREATE);

        if (bind_new_label != null) {
            bind_new_label.unbind ();
        }
        bind_new_label = panel.bind_property ("new-label",
                                              header_bar,
                                              "new-label",
                                              SYNC_CREATE);

        stack.visible_child.grab_focus ();
    }
}

} // namespace Clocks
