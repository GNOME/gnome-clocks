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

private struct AlarmTime {
    public int hour;
    public int minute;
}

private class Item : Object, ContentItem {
    // FIXME: should we add a "MISSED" state where the alarm stopped
    // ringing but we keep showing the ringing panel?
    public enum State {
        READY,
        RINGING,
        SNOOZING
    }

    public bool editing { get; set; default = false; }

    public string id { get; construct set; }

    public int snooze_minutes { get; set; default = 10; }

    public int ring_minutes { get; set; default = 5; }

    public string? name {
        get {
            return _name;
        }

        set {
            _name = (string) value;
            setup_bell ();
        }
    }

    public AlarmTime time { get; set; }

    private Utils.Weekdays? _days;
    public Utils.Weekdays? days {
        get {
            return _days;
        }

        set {
            _days = value;
            notify_property ("days-label");
        }
    }

    public State state { get; private set; }

    public string time_label {
         owned get {
            return Utils.WallClock.get_default ().format_time (alarm_time, false);
         }
    }

    public string snooze_time_label {
         owned get {
            return Utils.WallClock.get_default ().format_time (snooze_time, false);
         }
    }

    public string? days_label {
         owned get {
            return days != null ? (string?) ((Utils.Weekdays) days).get_label () : null;
         }
    }

    [CCode (notify = false)]
    public bool active {
        get {
            return _active && !this.editing;
        }

        set {
            if (value != _active) {
                _active = value;

                reset ();
                if (!active && state == State.RINGING) {
                    stop ();
                }

                notify_property ("active");
            }
        }
    }

    private string _name;
    private bool _active = true;
    private GLib.DateTime alarm_time;
    private GLib.DateTime snooze_time;
    private GLib.DateTime ring_end_time;
    private Utils.Bell bell;
    private GLib.Notification notification;

    public Item (string? id = null) {
        var guid = id != null ? (string) id : GLib.DBus.generate_guid ();
        Object (id: guid);
    }

    private void setup_bell () {
        bell = new Utils.Bell (GLib.File.new_for_uri ("resource://org/gnome/clocks/sounds/alarm-clock-elapsed.oga"));
        notification = new GLib.Notification (_("Alarm"));
        notification.set_body (name);
        notification.set_priority (HIGH);
        notification.add_button (_("Stop"), "app.stop-alarm::".concat (id));
        notification.add_button (_("Snooze"), "app.snooze-alarm::".concat (id));
    }

    public void reset () {
        update_alarm_time ();
        update_snooze_time (alarm_time);
        state = State.READY;
    }

    private void update_alarm_time () {
        var wallclock = Utils.WallClock.get_default ();
        var now = wallclock.date_time;
        var dt = new GLib.DateTime (wallclock.timezone,
                                    now.get_year (),
                                    now.get_month (),
                                    now.get_day_of_month (),
                                    time.hour,
                                    time.minute,
                                    0);

        if (days == null || ((Utils.Weekdays) days).empty) {
            // Alarm without days.
            if (dt.compare (now) <= 0) {
                // Time already passed, ring tomorrow.
                dt = dt.add_days (1);
            }
        } else {
            // Alarm with at least one day set.
            // Find the next possible day for ringing
            while (dt.compare (now) <= 0 || ! ((Utils.Weekdays) days).get ((Utils.Weekdays.Day) (dt.get_day_of_week () - 1))) {
                dt = dt.add_days (1);
            }
        }

        alarm_time = dt;
    }

    private void update_snooze_time (GLib.DateTime start_time) {
        snooze_time = start_time.add_minutes (snooze_minutes);
    }

    public virtual signal void ring () {
        var app = (Clocks.Application) GLib.Application.get_default ();
        app.send_notification ("alarm-clock-elapsed", notification);
        bell.ring ();
    }

    private void start_ringing (GLib.DateTime now) {
        update_snooze_time (now);
        ring_end_time = now.add_minutes (ring_minutes);
        state = State.RINGING;
        ring ();
    }

    public void snooze () {
        bell.stop ();
        state = State.SNOOZING;
    }

    public void stop () {
        bell.stop ();
        update_snooze_time (alarm_time);
        state = State.READY;
    }

    private bool compare_with_item (Item i) {
        return (this.alarm_time.compare (i.alarm_time) == 0 && (this.active || this.editing) && i.active);
    }

    public bool check_duplicate_alarm (List<Item> alarms) {
        update_alarm_time ();

        foreach (var item in alarms) {
            if (this.compare_with_item (item)) {
                return true;
            }
        }
        return false;
    }

    // Update the state and ringing time. Ring or stop
    // depending on the current time.
    // Returns true if the state changed, false otherwise.
    public bool tick () {
        if (!active) {
            return false;
        }

        State last_state = state;

        var wallclock = Utils.WallClock.get_default ();
        var now = wallclock.date_time;

        if (state == State.RINGING && now.compare (ring_end_time) > 0) {
            stop ();
        }

        if (state == State.SNOOZING && now.compare (snooze_time) > 0) {
            start_ringing (now);
        }

        if (state == State.READY && now.compare (alarm_time) > 0) {
            start_ringing (now);
            update_alarm_time (); // reschedule for the next repeat
        }

        return state != last_state;
    }

    public void serialize (GLib.VariantBuilder builder) {
        builder.open (new GLib.VariantType ("a{sv}"));
        builder.add ("{sv}", "name", new GLib.Variant.string ((string) name));
        builder.add ("{sv}", "id", new GLib.Variant.string (id));
        builder.add ("{sv}", "active", new GLib.Variant.boolean (active));
        builder.add ("{sv}", "hour", new GLib.Variant.int32 (time.hour));
        builder.add ("{sv}", "minute", new GLib.Variant.int32 (time.minute));
        builder.add ("{sv}", "days", ((Utils.Weekdays) days).serialize ());
        builder.add ("{sv}", "snooze_minutes", new GLib.Variant.int32 (snooze_minutes));
        builder.add ("{sv}", "ring_minutes", new GLib.Variant.int32 (ring_minutes));
        builder.close ();
    }

    public static ContentItem? deserialize (Variant alarm_variant) {
        string key;
        Variant val;
        string? name = null;
        string? id = null;
        bool active = true;
        int hour = -1;
        int minute = -1;
        int snooze_minutes = 10;
        int ring_minutes = 5;
        Utils.Weekdays? days = null;

        var iter = alarm_variant.iterator ();
        while (iter.next ("{sv}", out key, out val)) {
            if (key == "name") {
                name = (string) val;
            } else if (key == "id") {
                id = (string) val;
            } else if (key == "active") {
                active = (bool) val;
            } else if (key == "hour") {
                hour = (int32) val;
            } else if (key == "minute") {
                minute = (int32) val;
            } else if (key == "days") {
                days = Utils.Weekdays.deserialize (val);
            } else if (key == "snooze_minutes") {
                snooze_minutes = (int32) val;
            } else if (key == "ring_minutes") {
                ring_minutes = (int32) val;
            }
        }

        if (hour >= 0 && minute >= 0) {
            Item alarm = new Item (id);
            alarm.name = name;
            alarm.active = active;
            alarm.time = { hour, minute };
            alarm.days = days;
            alarm.ring_minutes = ring_minutes;
            alarm.snooze_minutes = snooze_minutes;
            alarm.reset ();
            return alarm;
        } else {
            warning ("Invalid alarm %s", name != null ? (string) name : "[unnamed]");
        }

        return null;
    }
}

} // namespace Alarm
} // namespace Clocks
