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

[GtkTemplate (ui = "/org/gnome/clocks/ui/timer-setup.ui")]
public class Setup : Gtk.Box {
    public signal void duration_changed (int seconds);
    [GtkChild]
    private Gtk.SpinButton h_spinbutton;
    [GtkChild]
    private Gtk.SpinButton m_spinbutton;
    [GtkChild]
    private Gtk.SpinButton s_spinbutton;

    public Setup () {
        var actions = new SimpleActionGroup ();
        // The duration here represends a number of minutes
        var duration_type = new GLib.VariantType ("i");
        var set_duration_action = new SimpleAction ("set-duration", duration_type);
        set_duration_action.activate.connect ((action, param) => {
            var total_minutes = (int32) param;
            var hours = total_minutes / 60;
            var minutes = total_minutes - hours * 60;
            this.h_spinbutton.value = hours;
            this.m_spinbutton.value = minutes;
        });
        actions.add_action (set_duration_action);
        insert_action_group ("timer-setup", actions);
    }

    private int get_duration () {
        /**
         * Gets the total duration of a timer in seconds
         * */

        var hours = (int)h_spinbutton.value;
        var minutes = (int)m_spinbutton.value;
        var seconds = (int)s_spinbutton.value;

        return hours * 3600 + minutes * 60 + seconds;
    }

    public Item get_timer () {
        return (new Item.from_seconds (get_duration (), ""));
    }

    [GtkCallback]
    private void update_duration () {
        duration_changed (get_duration ());
    }

    [GtkCallback]
    private bool show_leading_zeros (Gtk.SpinButton spin_button) {
        spin_button.set_text ("%02i".printf (spin_button.get_value_as_int ()));
        return true;
    }

    [GtkCallback]
    private int input_minutes (Gtk.SpinButton spin_button, out double new_value) {
        int entered_value = int.parse (spin_button.get_text ());

        // if input entered is not within bounds then it will carry the
        // extra portion to hours field
        if (entered_value > 59) {
           int current_hours = h_spinbutton.get_value_as_int ();
           h_spinbutton.set_value (double.min (99, current_hours + entered_value / 60));
        }
        new_value = entered_value % 60;
        return 1;
    }


    [GtkCallback]
    private int input_seconds (Gtk.SpinButton spin_button, out double new_value) {
        int entered_value = int.parse (spin_button.get_text ());

        // if input entered is not within bounds then it will carry the
        // extra portion to minutes field and hours field accordingly
        if (entered_value > 59) {
            int current_minutes = m_spinbutton.get_value_as_int ();
            int new_minutes = current_minutes + entered_value / 60;
            if (new_minutes > 59) {
                int current_hours = h_spinbutton.get_value_as_int ();
                h_spinbutton.set_value (double.min (99, current_hours + new_minutes / 60));
                new_minutes = new_minutes % 60;
            }
            m_spinbutton.set_value (new_minutes);

        }
        new_value = entered_value % 60;
        return 1;
    }
}

} // namespace Timer
} // namespace Clocks
