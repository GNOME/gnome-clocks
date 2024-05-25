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

[GtkTemplate (ui = "/org/gnome/clocks/ui/alarm-face.ui")]
public class Face : Adw.Bin, Clocks.Clock {
    public PanelId panel_id { get; construct set; }
    public ButtonMode button_mode { get; set; default = NEW; }
    // Translators: Tooltip for the + button
    public string? new_label { get; default = _("New Alarm"); }

    private ContentStore alarms;
    private Gtk.SortListModel sorted_alarms;
    private GLib.Settings settings;
    [GtkChild]
    private unowned Gtk.Widget empty_view;
    [GtkChild]
    private unowned Gtk.ListBox listbox;
    [GtkChild]
    private unowned Gtk.ScrolledWindow list_view;
    [GtkChild]
    private unowned Gtk.Stack stack;
    private Adw.Toast? ring_time_toast;
    private Alarm.Item? ring_time_toast_alarm;

    construct {
        panel_id = ALARM;

        alarms = new ContentStore ();
        settings = new GLib.Settings ("org.gnome.clocks");

        sorted_alarms = new Gtk.SortListModel (
            alarms,
            new Gtk.CustomSorter ((a, b) => Item.compare ((Item) a, (Item) b))
        );

        var app = (!) GLib.Application.get_default ();
        var action = (GLib.SimpleAction) app.lookup_action ("stop-alarm");
        action.activate.connect ((action, param) => {
            var a = alarms.find ((a) => {
                return ((Item) a).id == (string) param;
            });

            if (a != null) {
                ((Item) a).stop ();
            }
        });

        action = (GLib.SimpleAction) app.lookup_action ("snooze-alarm");
        action.activate.connect ((action, param) => {
            var a = alarms.find ((a) => {
                return ((Item) a).id == (string) param;
            });

            if (a != null) {
                ((Item) a).snooze ();
            }
        });

        listbox.bind_model (sorted_alarms, (item) => {
            var row = new Row ((Item) item);

            item.notify["ring-time"].connect (() => {
                show_ring_time_toast ((Item) item);
                save ();
            });

            row.remove_alarm.connect (() => {
                alarms.delete_item ((Item) item);
                if (ring_time_toast != null && item == ring_time_toast_alarm) {
                    ring_time_toast_alarm = null;
                    ring_time_toast.dismiss ();
                }
                save ();
            });

            return row;
        });

        listbox.row_activated.connect ((row) => {
           var alarm = ((Row) row).alarm;
           this.edit (alarm);
        });

        load ();

        alarms.items_changed.connect ((position, removed, added) => {
            save ();
            reset_view ();
        });

        reset_view ();

        // Start ticking...
        Utils.WallClock.get_default ().tick.connect (() => {
            alarms.foreach ((i) => {
                var a = (Item)i;
                if (a.tick ()) {
                    if (a.state == Item.State.RINGING) {
                        ring (a);
                    }
                }
            });
        });
    }

    internal signal void ring (Item item);

    private void connect_item (Item item) {
        item.notify["time"].connect (() => {
            sorted_alarms.sorter.changed (DIFFERENT);
        });
    }

    private void load () {
        alarms.deserialize (settings.get_value ("alarms"), Item.deserialize);

        alarms.foreach (item => connect_item ((Item) item));
    }

    private void save () {
        settings.set_value ("alarms", alarms.serialize ());
    }

    private void show_ring_time_toast (Item alarm) {
        if (alarm.ring_time == null) {
            return;
        }

        var window = (Clocks.Window) get_root ();
        var now = new GLib.DateTime.now ();
        var time_left_string = Utils.format_time_span (alarm.ring_time.difference (now));
        if (ring_time_toast == null) {
            ring_time_toast = new Adw.Toast ("");
        } else {
            ring_time_toast.dismiss ();
        }

        ring_time_toast.set_title (_("Alarm set for %s from now").printf (time_left_string));
        ring_time_toast_alarm = alarm;

        ulong handler_id1 = 0;
        ulong handler_id2 = 0;
        handler_id1 = ring_time_toast.dismissed.connect (() => {
            if (alarm == ring_time_toast_alarm) {
                ring_time_toast_alarm = null;
            }
            ring_time_toast.disconnect (handler_id1);
            alarm.disconnect (handler_id2);
        });

        handler_id2 = alarm.notify["active"].connect (() => {
            if (alarm == ring_time_toast_alarm && !alarm.active) {
                ring_time_toast.dismiss ();
                ring_time_toast_alarm = null;
            }
        });

        window.add_toast (ring_time_toast);
    }

    internal void edit (Item alarm) {
        var dialog = new SetupDialog (alarm, alarms);

        dialog.response.connect ((dialog, response) => {
            if (response == Gtk.ResponseType.OK) {
                ((SetupDialog) dialog).apply_to_alarm (alarm);
                // Activate the alarm after editing it
                alarm.active = true;
                save ();
            } else if (response == DELETE_ALARM) {
                alarms.delete_item (alarm);
                save ();
            }
            dialog.close ();
        });
        dialog.present (get_root ());
    }

    private void reset_view () {
        stack.visible_child = alarms.get_n_items () == 0 ? empty_view : list_view;
    }

    public void activate_new () {
        var dialog = new SetupDialog (null, alarms);
        dialog.response.connect ((dialog, response) => {
            if (response == Gtk.ResponseType.OK) {
                var alarm = new Item ();
                ((SetupDialog) dialog).apply_to_alarm (alarm);
                alarms.add (alarm);
                connect_item (alarm);
                // We need to send the toast manually since the ring time doesn't change
                show_ring_time_toast (alarm);
                save ();
            }
            dialog.close ();
        });
        dialog.present (get_root ());
    }
}

} // namespace Alarm
} // namespace Clocks
