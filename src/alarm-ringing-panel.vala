/*
 * Copyright (C) 2013  Paolo Borelli <pborelli@gnome.org>
 * Copyright (C) 2020  Zander Brown <zbrown@gnome.org>
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
namespace Alarm {

[GtkTemplate (ui = "/org/gnome/clocks/ui/alarm-ringing-panel.ui")]
private class RingingPanel : Adw.Bin {
    public Item? alarm {
        get {
            return _alarm;
        }
        set {
            if (_alarm != null) {
                ((Item) _alarm).disconnect (alarm_state_handler);
            }

            _alarm = value;

            if (_alarm != null) {
                alarm_state_handler = ((Item) _alarm).notify["state"].connect (() => {
                    if (((Item) _alarm).state != Item.State.RINGING) {
                        dismiss ();
                    }
                });

                stop_button.action_target = ((Item) _alarm).id;
                stop_button.action_name = "app.stop-alarm";

                snooze_button.action_target = ((Item) _alarm).id;
                snooze_button.action_name = "app.snooze-alarm";
            }

            update ();
        }
    }

    private Item? _alarm;
    private ulong alarm_state_handler;
    [GtkChild]
    private unowned Gtk.Label title_label;
    [GtkChild]
    private unowned Gtk.Label time_label;
    [GtkChild]
    private unowned Gtk.Button stop_button;
    [GtkChild]
    private unowned Gtk.Button snooze_button;

    construct {
        // Start ticking...
        Utils.WallClock.get_default ().tick.connect (update);
    }

    public virtual signal void dismiss () {
        alarm = null;
    }

    private void update () {
        if (alarm != null) {
            title_label.label = (string) ((Item) alarm).name;
            if (((Item) alarm).state == SNOOZING) {
                time_label.label = ((Item) alarm).ring_time_label;
            } else {
                time_label.label = ((Item) alarm).time_label;
            }
        } else {
            title_label.label = "";
            time_label.label = "";
        }
    }
}

} // namespace Alarm
} // namespace Clocks
