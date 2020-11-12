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
using Hdy;

namespace Clocks {
namespace Alarm {

// Response used for the "Delete Alarm" button in the edit dialogue
const int DELETE_ALARM = 2;

private class Duration : Object {
    public int minutes { get; set ; default = 0; }
    public string label { get; set; }

    public Duration (int minutes, string label) {
        this.minutes = minutes;
        this.label = label;
    }
}

private class DurationModel : ListModel, Object {
    Duration store[6];

    construct {
        store[0] = new Duration (1, _("1 minute"));
        store[1] = new Duration (5, _("5 minutes"));
        store[2] = new Duration (10, _("10 minutes"));
        store[3] = new Duration (15, _("15 minutes"));
        store[4] = new Duration (20, _("20 minutes"));
        store[5] = new Duration (30, _("30 minutes"));
    }

    public Type get_item_type () {
        return typeof (Duration);
    }

    public uint get_n_items () {
        return 6;
    }

    public Object? get_item (uint n) {
        if (n > 5) {
            return null;
        }
        return store[n];
    }

    public int find_by_duration (int minutes) {
        for (var i = 0; i < get_n_items (); i++) {
            var d = (Duration) get_item (i);
            if (d.minutes == minutes) {
                return i;
            }
        }
        return -1;
    }
}

[GtkTemplate (ui = "/org/gnome/clocks/ui/alarm-setup-dialog.ui")]
private class SetupDialog : Gtk.Dialog {
    private Utils.WallClock.Format format;
    public Item alarm { get; set; }
    [GtkChild]
    private Gtk.Grid time_grid;
    [GtkChild]
    private Gtk.SpinButton h_spinbutton;
    [GtkChild]
    private Gtk.SpinButton m_spinbutton;
    [GtkChild]
    private Gtk.Entry name_entry;
    [GtkChild]
    private Hdy.ComboRow snooze_duration;
    [GtkChild]
    private Hdy.ComboRow ring_duration;
    private AmPmToggleButton am_pm_button;
    [GtkChild]
    private DayPickerRow repeats;
    [GtkChild]
    private Gtk.Stack am_pm_stack;
    [GtkChild]
    private Gtk.Revealer label_revealer;
    [GtkChild]
    private Gtk.Button delete_button;
    private List<Item> other_alarms;
    private DurationModel duration_model;

    static construct {
        typeof (DayPickerRow).ensure ();
    }

    public SetupDialog (Gtk.Window parent, Item alarm, ListModel all_alarms, bool edit_alarm = false) {
        Object (transient_for: parent,
                alarm: alarm,
                title: edit_alarm ? _("Edit Alarm") : _("New Alarm"),
                use_header_bar: 1);

        add_button (_("Cancel"), Gtk.ResponseType.CANCEL);
        if (edit_alarm) {
            add_button (_("Done"), Gtk.ResponseType.OK);
        } else {
            add_button (_("Add"), Gtk.ResponseType.OK);
        }
        set_default_response (Gtk.ResponseType.OK);

        delete_button.visible = edit_alarm;

        other_alarms = new List<Item> ();
        var n = all_alarms.get_n_items ();
        for (int i = 0; i < n; i++) {
            var item = (Item) all_alarms.get_object (i);
            if (alarm != item) {
                other_alarms.prepend ((Item) all_alarms.get_object (i));
            }
        }

        duration_model = new DurationModel ();

        ring_duration.bind_name_model (duration_model, (item) => {
            return ((Duration) item).label;
        });

        snooze_duration.bind_name_model (duration_model, (item) => {
            return ((Duration) item).label;
        });

        // Force LTR since we do not want to reverse [hh] : [mm]
        time_grid.set_direction (Gtk.TextDirection.LTR);

        format = Utils.WallClock.get_default ().format;
        am_pm_button = new AmPmToggleButton ();
        am_pm_button.clicked.connect (() => {
            avoid_duplicate_alarm ();
        });

        if (format == Utils.WallClock.Format.TWENTYFOUR) {
            h_spinbutton.set_range (0, 23);
        } else {
            h_spinbutton.set_range (1, 12);
            am_pm_button.hexpand = false;
            am_pm_button.vexpand = false;
            am_pm_button.halign = Gtk.Align.CENTER;
            am_pm_button.valign = Gtk.Align.CENTER;
            am_pm_stack.add (am_pm_button);
            am_pm_stack.visible_child = am_pm_button;
        }

        set_from_alarm ();
    }

    // Sets up the dialog to show the values of alarm.
    public void set_from_alarm () {
      var hour = alarm.time.hour;
      var minute = alarm.time.minute;
        // Set the time.
        if (format == Utils.WallClock.Format.TWELVE) {
            if (hour < 12) {
                am_pm_button.choice = AmPmToggleButton.AmPm.AM;
            } else {
                am_pm_button.choice = AmPmToggleButton.AmPm.PM;
                hour -= 12;
            }

            if (hour == 0) {
                hour = 12;
            }
        }
        ring_duration.set_selected_index (duration_model.find_by_duration (alarm.ring_minutes));
        snooze_duration.set_selected_index (duration_model.find_by_duration (alarm.snooze_minutes));

        h_spinbutton.set_value (hour);
        m_spinbutton.set_value (minute);

        // Set the name.
        name_entry.set_text ((string) alarm.name);

        if (alarm.days != null) {
            repeats.load ((Utils.Weekdays) alarm.days);
        }
    }

    // Sets alarm according to the current dialog settings.
    public void apply_to_alarm () {
        var name = name_entry.get_text ();
        var hour = h_spinbutton.get_value_as_int ();
        var minute = m_spinbutton.get_value_as_int ();
        var snooze_item = (Duration) duration_model.get_item (snooze_duration.get_selected_index ());
        var ring_item = (Duration) duration_model.get_item (ring_duration.get_selected_index ());

        if (format == Utils.WallClock.Format.TWELVE) {
            var choice = am_pm_button.choice;
            if (choice == AmPmToggleButton.AmPm.AM && hour == 12) {
                hour = 0;
            } else if (choice == AmPmToggleButton.AmPm.PM && hour != 12) {
                hour += 12;
            }
        }

        AlarmTime time = { hour, minute };

        var days = repeats.store ();

        alarm.freeze_notify ();

        alarm.name = name;
        alarm.time = time;
        alarm.days = days;
        alarm.snooze_minutes = snooze_item.minutes;
        alarm.ring_minutes = ring_item.minutes;

        // Force update of alarm_time before notifying the changes
        alarm.reset ();

        alarm.thaw_notify ();
    }

    private void avoid_duplicate_alarm () {
        apply_to_alarm ();

        var duplicate = alarm.check_duplicate_alarm (other_alarms);
        this.set_response_sensitive (Gtk.ResponseType.OK, !duplicate);
        label_revealer.set_reveal_child (duplicate);
    }

    [GtkCallback]
    private void days_changed () {
        avoid_duplicate_alarm ();
    }

    [GtkCallback]
    private void entry_changed (Gtk.Editable editable) {
        avoid_duplicate_alarm ();
    }

    [GtkCallback]
    private void spinbuttons_changed (Gtk.Editable editable) {
        avoid_duplicate_alarm ();
    }

    [GtkCallback]
    private bool show_leading_zeros (Gtk.SpinButton spin_button) {
        spin_button.set_text ("%02i".printf (spin_button.get_value_as_int ()));
        return true;
    }

    [GtkCallback]
    private void delete () {
        response (DELETE_ALARM);
    }
}

} // namespace Alarm
} // namespace Clocks
