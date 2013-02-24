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

    private Toolbar toolbar;
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

        toolbar = new Toolbar ();

        world = new World.MainPanel (toolbar);
        alarm = new Alarm.MainPanel (toolbar);
        stopwatch = new Stopwatch.MainPanel (toolbar);
        timer = new Timer.MainPanel (toolbar);

        toolbar.add_clock (world);
        toolbar.add_clock (alarm);
        toolbar.add_clock (stopwatch);
        toolbar.add_clock (timer);

        stack = new Gd.Stack ();
        stack.duration = 0;
        stack.add (world);
        stack.add (alarm);
        stack.add (stopwatch);
        stack.add (timer);

        toolbar.clock_changed.connect ((c) => {
            stack.visible_child = (Gtk.Widget) c;
        });

        var id = stack.notify["visible-child"].connect (() => {
            update_toolbar ();
        });

        toolbar.notify["mode"].connect (() => {
            update_toolbar ();
        });

        toolbar.destroy.connect(() => {
            stack.disconnect (id);
            id = 0;
        });

        alarm.ring.connect ((w) => {
            stack.visible_child = w;
        });

        timer.ring.connect ((w) => {
            stack.visible_child = w;
        });

        stack.visible_child = world;
        world.update_toolbar ();

        var frame = new Gtk.Frame (null);
        frame.get_style_context ().add_class ("clocks-content-view");
        frame.get_style_context ().add_class ("view");
        frame.get_style_context ().add_class ("content-view");
        frame.add (stack);

        var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        vbox.pack_start (toolbar, false, false, 0);
        vbox.pack_end (frame, true, true, 0);
        add (vbox);

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
                               "program-name", _("Gnome Clocks"),
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

    private void update_toolbar () {
        toolbar.clear ();
        var clock = (Clock) stack.visible_child;
        if (clock != null) {
            clock.update_toolbar ();
        }
    }
}

} // namespace Clocks
