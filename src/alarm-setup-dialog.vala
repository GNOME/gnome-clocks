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
using Adw;

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
private class SetupDialog : Adw.Dialog {
    private Utils.WallClock.Format format;
    [GtkChild]
    private unowned Gtk.Box time_box;
    [GtkChild]
    private unowned Gtk.SpinButton h_spinbutton;
    [GtkChild]
    private unowned Gtk.SpinButton m_spinbutton;
    [GtkChild]
    private unowned Adw.EntryRow name_entry;
    [GtkChild]
    private unowned Adw.ComboRow snooze_duration;
    [GtkChild]
    private unowned Adw.ComboRow ring_duration;
    private AmPmToggleButton am_pm_button;
    [GtkChild]
    private unowned DayPickerRow repeats;
    [GtkChild]
    private unowned Adw.Bin am_pm_bin;
    [GtkChild]
    private unowned Adw.Banner banner;
    [GtkChild]
    private unowned Adw.PreferencesGroup delete_group;
    [GtkChild]
    private unowned Gtk.Button ok_button;
    private List<Item> other_alarms;
    private DurationModel duration_model;

    static construct {
        typeof (DayPickerRow).ensure ();
        typeof (Duration).ensure ();
    }

    public SetupDialog (Item? alarm, ListModel all_alarms) {
        Object (title: alarm != null ? _("Edit Alarm") : _("New Alarm"));

        if (alarm != null) {
            ok_button.label = _("_Done");
        }

        delete_group.visible = alarm != null;

        other_alarms = new List<Item> ();
        var n = all_alarms.get_n_items ();
        for (int i = 0; i < n; i++) {
            var item = (Item) all_alarms.get_object (i);
            if (alarm != item) {
                other_alarms.prepend ((Item) all_alarms.get_object (i));
            }
        }

        duration_model = new DurationModel ();

        var expression = new Gtk.CClosureExpression (typeof (string),
                                                     null, {},
                                                     (Callback) duration_label,
                                                     null, null);

        snooze_duration.set_expression (expression);
        snooze_duration.set_model (duration_model);

        ring_duration.set_expression (expression);
        ring_duration.set_model (duration_model);

        // Force LTR since we do not want to reverse [hh] : [mm]
        time_box.set_direction (Gtk.TextDirection.LTR);

        format = Utils.WallClock.get_default ().format;
        am_pm_button = new AmPmToggleButton ();
        am_pm_button.clicked.connect (() => {
            avoid_duplicate_alarm ();
        });

        if (format == Utils.WallClock.Format.TWENTYFOUR) {
            h_spinbutton.set_range (0, 23);
            am_pm_bin.hide ();
        } else {
            h_spinbutton.set_range (1, 12);
            am_pm_button.hexpand = false;
            am_pm_button.vexpand = false;
            am_pm_button.halign = Gtk.Align.CENTER;
            am_pm_button.valign = Gtk.Align.CENTER;
            am_pm_bin.show ();
            am_pm_bin.set_child (am_pm_button);
        }

        set_from_alarm (alarm);
    }

    private static string duration_label (Duration item) {
        return item.label;
    }

    // Sets up the dialog to show the values of alarm.
    public void set_from_alarm (Item? alarm) {
        string? name;
        bool active;
        int hour;
        int minute;
        int snooze_minutes;
        int ring_minutes;
        unowned Utils.Weekdays? days;

        if (alarm == null) {
            var wc = Utils.WallClock.get_default ();
            // Not great but we can't null it
            name = "";
            hour = wc.date_time.get_hour ();
            minute = wc.date_time.get_minute ();
            days = null;
            active = true;
            ring_minutes = 5;
            snooze_minutes = 10;
        } else {
            name = ((Item) alarm).name;
            hour = ((Item) alarm).time.hour;
            minute = ((Item) alarm).time.minute;
            days = ((Item) alarm).days;
            active = ((Item) alarm).active;
            ring_minutes = ((Item) alarm).ring_minutes;
            snooze_minutes = ((Item) alarm).snooze_minutes;
        }

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
        ring_duration.set_selected (duration_model.find_by_duration (ring_minutes));
        snooze_duration.set_selected (duration_model.find_by_duration (snooze_minutes));

        h_spinbutton.set_value (hour);
        m_spinbutton.set_value (minute);

        // Set the name.
        name_entry.set_text ((string) name);

        if (days != null) {
            repeats.load ((Utils.Weekdays) days);
        }
    }

    // Sets alarm according to the current dialog settings.
    public void apply_to_alarm (Item alarm) {
        var name = name_entry.get_text ();
        var hour = h_spinbutton.get_value_as_int ();
        var minute = m_spinbutton.get_value_as_int ();
        var snooze_item = (Duration) duration_model.get_item (snooze_duration.get_selected ());
        var ring_item = (Duration) duration_model.get_item (ring_duration.get_selected ());

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

        // Force update of ring_time before notifying the changes
        alarm.reset ();

        alarm.thaw_notify ();
    }

    private void avoid_duplicate_alarm () {
        var alarm = new Item ();
        apply_to_alarm (alarm);

        var duplicate = alarm.check_duplicate_alarm (other_alarms);
        ok_button.sensitive = !duplicate;
        banner.set_revealed (duplicate);
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

    [GtkCallback]
    private void add () {
        response (Gtk.ResponseType.OK);
    }

    [GtkCallback]
    private void cancel () {
        response (Gtk.ResponseType.CANCEL);
    }

    public signal void response (int response);
}

} // namespace Alarm
} // namespace Clocks
