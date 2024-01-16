/*
 * Copyright (C) 2013  Paolo Borelli <pborelli@gnome.org>
 * Copyright (C) 2020  Bilal Elmoussaoui <bilal.elmoussaoui@gnome.org>
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
namespace Timer {

[GtkTemplate (ui = "/org/gnome/clocks/ui/timer-setup-dialog.ui")]
public class SetupDialog: Adw.Dialog {
    public Setup timer_setup;

    [GtkChild]
    private unowned Gtk.Box timer_box;
    [GtkChild]
    private unowned Gtk.Button start_button;

    public SetupDialog () {
        timer_setup = new Setup ();
        timer_box.prepend (timer_setup);
        timer_setup.duration_changed.connect ((duration) => {
            start_button.sensitive = duration != 0;
        });
        timer_setup.start_timer.connect (() => {
            done ();
        });
    }

    [GtkCallback]
    private void create_clicked () {
        done ();
    }

    public signal void done ();
}

} // namespace Timer
} // namespace Clocks
