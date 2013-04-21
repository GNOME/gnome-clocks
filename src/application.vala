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

public class Application : Gtk.Application {
    const GLib.ActionEntry[] action_entries = {
        { "quit", on_quit_activate }
    };

    private Window window;

    public Application () {
        Object (application_id: "org.gnome.clocks", flags: ApplicationFlags.IS_SERVICE);

        add_action_entries (action_entries, this);
    }

    protected override void activate () {
        if (window == null) {
            window = new Window (this);
        }
        window.present ();
    }

    protected override void startup () {
        base.startup ();

        // FIXME: move the css in gnome-theme-extras
        var css_provider = Utils.load_css ("gnome-clocks.css");
        Gtk.StyleContext.add_provider_for_screen (Gdk.Screen.get_default(),
                                                  css_provider,
                                                  Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var builder = Utils.load_ui ("menu.ui");
        var app_menu = builder.get_object ("appmenu") as MenuModel;
        set_app_menu (app_menu);

        add_accelerator ("<Primary>a", "win.select-all", null);
    }

    void on_quit_activate () {
        quit ();
    }
}

} // namespace Clocks
