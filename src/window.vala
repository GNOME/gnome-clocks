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
    private const GLib.ActionEntry[] action_entries = {
        // app menu
        { "new", on_new_activate },
        { "help", on_help_activate },
        { "about", on_about_activate },

        // selection menu
        { "select-all", on_select_all_activate },
        { "select-none", on_select_none_activate }
    };

    [GtkChild]
    private HeaderBar header_bar;
    [GtkChild]
    private Gtk.Stack stack;
    [GtkChild]
    private Gtk.StackSwitcher stack_switcher;
    private GLib.Settings settings;
    private Gtk.Widget[] panels;

    public Window (Application app) {
        Object (application: app);

        add_action_entries (action_entries, this);

        settings = new Settings ("org.gnome.clocks.state.window");
        settings.delay ();

        destroy.connect(() => {
            settings.apply ();
        });

        // Setup window geometry saving
        Gdk.WindowState window_state = (Gdk.WindowState)settings.get_int ("state");
        if (Gdk.WindowState.MAXIMIZED in window_state) {
            maximize ();
        }

        int width, height;
        settings.get ("size", "(ii)", out width, out height);
        resize (width, height);

        panels = new Gtk.Widget[N_PANELS];

        panels[PanelId.WORLD] = new World.Face (header_bar);
        panels[PanelId.ALARM] =  new Alarm.Face (header_bar);
        panels[PanelId.STOPWATCH] = new Stopwatch.Face (header_bar);
        panels[PanelId.TIMER] = new Timer.Face (header_bar);

        var world = (World.Face)panels[PanelId.WORLD];
        var alarm = (Alarm.Face)panels[PanelId.ALARM];
        var stopwatch = (Stopwatch.Face)panels[PanelId.STOPWATCH];
        var timer = (Timer.Face)panels[PanelId.TIMER];

        foreach (var clock in panels) {
            stack.add_titled (clock, ((Clock)clock).label, ((Clock)clock).label);
        }

        stack_switcher.set_stack (stack);

        var stack_id = stack.notify["visible-child"].connect (() => {
            var help_overlay = get_help_overlay ();
            help_overlay.view_name = Type.from_instance(stack.visible_child).name();
            update_header_bar ();
        });

        var header_bar_id = header_bar.notify["mode"].connect (() => {
            update_header_bar ();
        });

        stack.destroy.connect(() => {
            header_bar.disconnect (header_bar_id);
            header_bar_id = 0;
            stack.disconnect (stack_id);
            stack_id = 0;
        });

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
                                     typeof(int), -1);
        Gtk.BindingEntry.add_signal (binding_set,
                                     Gdk.Key.Page_Down,
                                     Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.MOD1_MASK,
                                     "change-page", 1,
                                     typeof(int), 1);

        stack.visible_child = panels[settings.get_enum ("panel-id")];

        update_header_bar ();

        show_all ();
    }

    [Signal(action = true)]
    public virtual signal void change_page (int offset) {
        int page;

        stack.child_get (stack.visible_child, "position", out page);
        page += offset;
        if (page >= 0 && page < panels.length) {
            stack.visible_child = panels[page];
        } else {
            stack.error_bell ();
        }
    }

    private void on_new_activate () {
        ((Clock) stack.visible_child).activate_new ();
    }

    private void on_select_all_activate () {
        ((Clock) stack.visible_child).activate_select_all ();
    }

    private void on_select_none_activate () {
        ((Clock) stack.visible_child).activate_select_none ();
    }

    public void show_world () {
        ((World.Face) panels[PanelId.WORLD]).reset_view ();
        stack.visible_child = panels[PanelId.WORLD];;
    }

    public void add_world_location (GWeather.Location location) {
        ((World.Face) panels[PanelId.WORLD]).add_location (location);
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
        const string copyright = "Copyright \xc2\xa9 2011 Collabora Ltd.\n" +
                                 "Copyright \xc2\xa9 2012-2013 Collabora Ltd., Seif Lotfy, Emily Gonyer\n" +
                                 "Eslam Mostafa, Paolo Borelli, Volker Sobek\n";

        const string authors[] = {
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
            null
        };

        Gtk.show_about_dialog (this,
                               "program-name", _("Clocks"),
                               "logo-icon-name", "org.gnome.clocks",
                               "version", Config.VERSION,
                               "comments", _("Utilities to help you with the time."),
                               "copyright", copyright,
                               "authors", authors,
                               "license-type", Gtk.License.GPL_2_0,
                               "wrap-license", false,
                               "translator-credits", _("translator-credits"),
                               null);
    }

    private void update_header_bar () {
        header_bar.clear ();

        var clock = (Clock) stack.visible_child;
        if (clock != null) {
            settings.set_enum ("panel-id", clock.panel_id);
            clock.update_header_bar ();
            ((Gtk.Widget) clock).grab_focus ();
        }

        if (header_bar.mode == HeaderBar.Mode.NORMAL) {
            header_bar.custom_title = stack_switcher;
        }

        header_bar.set_show_close_button (header_bar.mode != HeaderBar.Mode.SELECTION);
    }
}

} // namespace Clocks
