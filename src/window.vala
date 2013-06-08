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
        { "about", on_about_activate },

        // selection menu
        { "select-all", on_select_all_activate },
        { "select-none", on_select_none_activate }
    };

    [GtkChild]
    private HeaderBar header_bar;
    [GtkChild]
    private Gd.Stack stack;
    private GLib.Settings settings;
    private Gtk.Widget[] panels;
    private Gtk.Separator separator;
    private Gtk.Button close_button;

    public Window (Application app) {
        Object (application: app);

        add_action_entries (action_entries, this);

        settings = new Settings ("org.gnome.clocks.state.window");

        // Setup window geometry saving
        Gdk.WindowState window_state = (Gdk.WindowState)settings.get_int ("state");
        if (Gdk.WindowState.MAXIMIZED in window_state) {
            maximize ();
        }

        int width, height;
        settings.get ("size", "(ii)", out width, out height);
        resize (width, height);

        panels = new Gtk.Widget[N_PANELS];

        panels[PanelId.WORLD] = new World.MainPanel (header_bar);
        panels[PanelId.ALARM] =  new Alarm.MainPanel (header_bar);
        panels[PanelId.STOPWATCH] = new Stopwatch.MainPanel (header_bar);
        panels[PanelId.TIMER] = new Timer.MainPanel (header_bar);

        foreach (var clock in panels) {
            stack.add_titled (clock, ((Clock)clock).label, ((Clock)clock).label);
        }

        header_bar.set_stack (stack);

        separator = new Gtk.Separator (Gtk.Orientation.VERTICAL);
        separator.no_show_all = true;
        separator.valign = Gtk.Align.FILL;
        header_bar.pack_end (separator);

        close_button = new Gtk.Button ();
        Gtk.Image close_image = new Gtk.Image.from_icon_name ("window-close-symbolic", Gtk.IconSize.MENU);
        close_button.set_image (close_image);
        close_button.get_style_context ().add_class ("image-button");
        close_button.relief = Gtk.ReliefStyle.NONE;
        close_button.valign = Gtk.Align.CENTER;
        close_button.clicked.connect (() => {
            Gdk.Event event;

            event = new Gdk.Event (Gdk.EventType.DESTROY);

            event.any.window = this.get_window ();
            event.any.send_event = 1;

            Gtk.main_do_event (event);
        });

        close_button.no_show_all = true;
        header_bar.pack_end (close_button);

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

        ((Alarm.MainPanel)panels[PanelId.ALARM]).ring.connect ((w) => {
            stack.visible_child = w;
        });

        ((Timer.MainPanel)panels[PanelId.TIMER]).ring.connect ((w) => {
            stack.visible_child = w;
        });

        stack.visible_child = panels[settings.get_enum ("panel-id")];

        update_header_bar ();

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

    protected override bool configure_event (Gdk.EventConfigure event) {
        if (get_realized () && !(Gdk.WindowState.MAXIMIZED in get_window ().get_state ())) {
            settings.set ("size", "(ii)", event.width, event.height);
        }

        return base.configure_event (event);
    }

    protected override bool window_state_event (Gdk.EventWindowState event) {
        settings.set_int ("state", event.new_window_state);
        return base.window_state_event (event);
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
            settings.set_enum ("panel-id", clock.panel_id);
            clock.update_header_bar ();
            ((Gtk.Widget) clock).grab_focus ();
        }

        if (header_bar.mode != HeaderBar.Mode.SELECTION) {
            separator.show ();
            close_button.show ();
        }
    }
}

} // namespace Clocks
