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

public class Window : Gtk.ApplicationWindow {
    // Default size is enough for two rows of three clocks
    private const int DEFAULT_WIDTH = 870;
    private const int DEFAULT_HEIGHT = 680;

    private const GLib.ActionEntry[] action_entries = {
        // app menu
        { "new", on_new_activate },
        { "about", on_about_activate },

        // selection menu
        { "select-all", on_select_all_activate },
        { "select-none", on_select_none_activate }
    };

    private HeaderBar header_bar;
    private Gd.Stack stack;
    private World.MainPanel world;
    private Alarm.MainPanel alarm;
    private Stopwatch.MainPanel stopwatch;
    private Timer.MainPanel timer;

    public Window (Application app) {
        Object (application: app, title: _("Clocks"));

        set_hide_titlebar_when_maximized (true);
        add_action_entries (action_entries, this);

        set_size_request (DEFAULT_WIDTH, DEFAULT_HEIGHT);

        var builder = Utils.load_ui ("window.ui");

        var main_panel = builder.get_object ("main_panel") as Gtk.Widget;
        header_bar = builder.get_object ("header_bar") as HeaderBar;
        stack = builder.get_object ("stack") as Gd.Stack;

        world = new World.MainPanel (header_bar);
        alarm = new Alarm.MainPanel (header_bar);
        stopwatch = new Stopwatch.MainPanel (header_bar);
        timer = new Timer.MainPanel (header_bar);

        stack.add_titled (world, world.label, world.label);
        stack.add_titled (alarm, alarm.label, alarm.label);
        stack.add_titled (stopwatch, stopwatch.label, stopwatch.label);
        stack.add_titled (timer, timer.label, timer.label);

        header_bar.set_stack (stack);

        var stack_id = stack.notify["visible-child"].connect (() => {
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
            stack.visible_child = w;
        });

        timer.ring.connect ((w) => {
            stack.visible_child = w;
        });

        stack.visible_child = world;
        update_header_bar ();

        add (main_panel);
        show_all ();
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

    public override bool key_press_event (Gdk.EventKey event) {
        uint keyval;
        if (((Gdk.Event*)(&event))->get_keyval (out keyval) && keyval == Gdk.Key.Escape) {
            return ((Clock) stack.visible_child).escape_pressed ();
        }

        return base.key_press_event (event);
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
                               "logo-icon-name", "gnome-clocks",
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
            clock.update_header_bar ();
            ((Gtk.Widget) clock).grab_focus ();
        }
    }
}

} // namespace Clocks
