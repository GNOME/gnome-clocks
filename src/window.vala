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
    private unowned Adw.Deck alarm_deck;
    [GtkChild]
    private unowned Adw.Deck world_deck;
    [GtkChild]
    private unowned Gtk.Box main_view;
    [GtkChild]
    private unowned Gtk.Stack stack;
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

    public Window (Application app) {
        Object (application: app);

        add_action_entries (ACTION_ENTRIES, this);

        settings = new Settings ("org.gnome.clocks.state.window");
        settings.delay ();

        // We need to set this manually, otherwise it fails in the devel version
        var builder = new Gtk.Builder.from_resource ("/org/gnome/clocks/gtk/help-overlay.ui");
        var dialog = (Gtk.ShortcutsWindow)builder.get_object ("help_overlay");
        set_help_overlay (dialog);

        // GSettings gives us the nick, which matches the stack page name
        stack.visible_child_name = settings.get_string ("panel-id");

        inited = true;

        header_bar.bind_property ("title", this, "title", SYNC_CREATE);

        pane_changed ();

        // Setup window geometry saving
        var window_state = (Gdk.WindowState) settings.get_int ("state");
        if (Gdk.WindowState.MAXIMIZED in window_state) {
            maximize ();
        } else {
            int width, height;
            settings.get ("size", "(ii)", out width, out height);
            resize (width, height);
        }

        world.show_standalone.connect ((w, l) => {
            stack.visible_child = w;
            world_standalone.location = l;
            world_deck.navigate (Adw.NavigationDirection.FORWARD);
        });

        alarm.ring.connect ((w, a) => {
            close_standalone ();
            stack.visible_child = w;
            alarm_ringing_panel.alarm = a;
            alarm_deck.visible_child = alarm_ringing_panel;
        });

        stopwatch.notify["state"].connect ((w) => {
            stack.child_set_property (stopwatch, "needs-attention", stopwatch.state == Stopwatch.Face.State.RUNNING);
        });

        timer.ring.connect ((w) => {
            close_standalone ();
            stack.visible_child = w;
        });


        timer.notify["is-running"].connect ((w) => {
            stack.child_set_property (timer, "needs-attention", timer.is_running);
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
                                     typeof (int), 1);

        Gtk.BindingEntry.add_signal (binding_set,
                                     Gdk.Key.@1,
                                     Gdk.ModifierType.MOD1_MASK,
                                     "set-page", 1,
                                     typeof (string), "world");
        Gtk.BindingEntry.add_signal (binding_set,
                                     Gdk.Key.@2,
                                     Gdk.ModifierType.MOD1_MASK,
                                     "set-page", 1,
                                     typeof (string), "alarm");
        Gtk.BindingEntry.add_signal (binding_set,
                                     Gdk.Key.@3,
                                     Gdk.ModifierType.MOD1_MASK,
                                     "set-page", 1,
                                     typeof (string), "stopwatch");
        Gtk.BindingEntry.add_signal (binding_set,
                                     Gdk.Key.@4,
                                     Gdk.ModifierType.MOD1_MASK,
                                     "set-page", 1,
                                     typeof (string), "timer");

        Gtk.StyleContext style = get_style_context ();
        if (Config.PROFILE == "Devel") {
            style.add_class ("devel");
        }
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
        world_deck.navigate (Adw.NavigationDirection.BACK);
    }

    public void show_world () {
        close_standalone ();
        stack.visible_child = world;
    }

    public void add_world_location (GWeather.Location location) {
        world.add_location (location);
    }

    public override void destroy () {
        settings.apply ();
    }

    public override bool delete_event (Gdk.EventAny event) {
        settings.apply ();

        return hide_on_delete ();
    }

    public override bool key_press_event (Gdk.EventKey event) {
        uint keyval;
        bool handled = false;

        if (((Gdk.Event)(event)).get_keyval (out keyval) && keyval == Gdk.Key.Escape) {
            if (world_deck.visible_child == main_view) {
                handled = ((Clock) stack.visible_child).escape_pressed ();
            } else {
                world_deck.navigate (Adw.NavigationDirection.BACK);
            }
        }

        if (handled) {
            return true;
        }

        return base.key_press_event (event);
    }

    public override bool button_release_event (Gdk.EventButton event) {
        const uint BUTTON_BACK = 8;
        uint button;

        if (((Gdk.Event) (event)).get_button (out button) && button == BUTTON_BACK) {
            on_back_activate ();
            return true;
        }

        return base.button_release_event (event);
    }

    protected override bool configure_event (Gdk.EventConfigure event) {
        if (get_realized () && !(Gdk.WindowState.MAXIMIZED in ((Gdk.Window) get_window ()).get_state ())) {
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
            Gtk.show_uri_on_window (this, "help:gnome-clocks", Gtk.get_current_event_time ());
        } catch (Error e) {
            warning (_("Failed to show help: %s"), e.message);
        }
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
        if (alarm_deck.visible_child == alarm_ringing_panel) {
            title = _("Alarm");
        } else if (world_deck.visible_child == world_standalone) {
            title = world_standalone.title;
        } else {
            title = _("Clocks");
        }

        deletable = (alarm_deck.visible_child != alarm_ringing_panel);
    }

    [GtkCallback]
    private void alarm_dismissed () {
        alarm_deck.visible_child = world_deck;
    }

    private void close_standalone () {
        world_deck.visible_child = main_view;
    }
}

} // namespace Clocks
