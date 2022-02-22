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

public class SetupDialog: Gtk.Dialog {
    public Setup timer_setup;

    public SetupDialog (Gtk.Window parent) {
        Object (modal: true, transient_for: parent, title: _("New Timer"), use_header_bar: 1);
        this.set_default_size (640, 360);

        add_button (_("Cancel"), Gtk.ResponseType.CANCEL);
        var create_button = add_button (_("Add"), Gtk.ResponseType.ACCEPT);
        this.set_response_sensitive (Gtk.ResponseType.ACCEPT, false);
        create_button.add_css_class ("suggested-action");

        timer_setup = new Setup ();
        this.get_content_area ().append (timer_setup);
        timer_setup.duration_changed.connect ((duration) => {
            this.set_response_sensitive (Gtk.ResponseType.ACCEPT, duration != 0);
        });
    }
}

} // namespace Timer
} // namespace Clocks
