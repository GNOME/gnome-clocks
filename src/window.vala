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
        // primary menu
        { "show-primary-menu", on_show_primary_menu_activate, null, "false", null },
        { "new", on_new_activate },
        { "help", on_help_activate },
        { "about", on_about_activate },

        // selection menu
        { "select-all", on_select_all_activate },
        { "select-none", on_select_none_activate }
    };

    [GtkChild]
    private Gtk.HeaderBar header_bar;
    [GtkChild]
    private Gtk.Stack headerbar_actions_stack;

    [GtkChild]
    private Gtk.Stack stack;
    [GtkChild]
    private Gtk.MenuButton menu_button;
    [GtkChild]
    private Hdy.ViewSwitcherBar switcher_bar;
    [GtkChild]
    private Hdy.Squeezer squeezer;
    [GtkChild]
    private Hdy.ViewSwitcher title_wide_switcher;
    [GtkChild]
    private Hdy.ViewSwitcher title_narrow_switcher;
    [GtkChild]
    private Gtk.Box title_text;

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
        set_title (_("Clocks"));

        panels = new Gtk.Widget[N_PANELS];

        panels[PanelId.WORLD] = new World.Face ();
        panels[PanelId.ALARM] =  new Alarm.Face ();
        panels[PanelId.STOPWATCH] = new Stopwatch.Face ();
        panels[PanelId.TIMER] = new Timer.Face ();

        var world = (World.Face)panels[PanelId.WORLD];
        var alarm = (Alarm.Face)panels[PanelId.ALARM];
        var stopwatch = (Stopwatch.Face)panels[PanelId.STOPWATCH];
        var timer = (Timer.Face)panels[PanelId.TIMER];

        foreach (var panel in panels) {
            stack.add_titled (panel, ((Clock)panel).label, ((Clock)panel).label);
            stack.child_set_property(panel, "icon-name", ((Clock)panel).icon_name);
            var header_actions_widget = ((Clock)panel).header_actions_widget;
            if (header_actions_widget != null) {
                headerbar_actions_stack.add_named (header_actions_widget,
                                                    ((Clock)panel).panel_id.to_string());
            }
        }

        var stack_id = stack.notify["visible-child"].connect (() => {
            var help_overlay = get_help_overlay ();
            help_overlay.view_name = Type.from_instance(stack.visible_child).name();
            update_header_bar ();
        });

        this.size_allocate.connect((widget, allocation) => {
            switcher_bar.set_reveal(allocation.width < 500);
            squeezer.set_child_enabled(title_wide_switcher, allocation.width > 800);
            squeezer.set_child_enabled(title_narrow_switcher, allocation.width > 500);
            squeezer.set_child_enabled(title_text, allocation.width <= 500);
        });

        stack.destroy.connect(() => {
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
            // stack.child_set_property (timer, "needs-attention", timer.state == Timer.Face.State.RUNNING);
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

        Gtk.StyleContext style = get_style_context ();
        if (Config.PROFILE == "Devel") {
            style.add_class ("devel");
        }

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

    private void on_show_primary_menu_activate (SimpleAction action) {
        var state = action.get_state ().get_boolean ();
        action.set_state (new Variant.boolean (!state));
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

    public override bool button_release_event (Gdk.EventButton event) {
        const uint BUTTON_BACK = 8;
        uint button;

        if (((Gdk.Event)(event)).get_button (out button) && button == BUTTON_BACK) {
            ((Clock) stack.visible_child).back ();
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
        const string copyright = "Copyright \xc2\xa9 2011 Collabora Ltd.\n" +
                                 "Copyright \xc2\xa9 2012-2013 Collabora Ltd., Seif Lotfy, Emily Gonyer\n" +
                                 "Eslam Mostafa, Paolo Borelli, Volker Sobek\n" + 
                                 "Copyright \xc2\xa9 2019 Bilal Elmoussaoui & Zander Brown et al";

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
                               "copyright", copyright,
                               "authors", authors,
                               "license-type", Gtk.License.GPL_2_0,
                               "wrap-license", false,
                               "translator-credits", _("translator-credits"),
                               null);
    }

    private void update_header_bar () {
        var clock = (Clock) stack.visible_child;
        var panel_id = clock.panel_id.to_string();
        if (headerbar_actions_stack.get_child_by_name(panel_id) != null) {
            headerbar_actions_stack.visible_child_name = clock.panel_id.to_string();
            headerbar_actions_stack.show();
        } else {
            headerbar_actions_stack.hide();
        }
        if (clock != null) {
            settings.set_enum ("panel-id", clock.panel_id);
            ((Gtk.Widget) clock).grab_focus ();
        }
    }
}

} // namespace Clocks
