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

    public bool is_eq (AlarmTime other) {
        return this.hour == other.hour && this.minute == other.minute;
    }

    public int compare (AlarmTime other) {
        int this_minutes = hour * 60 + minute;
        int other_minutes = other.hour * 60 + other.minute;

        if (this_minutes < other_minutes)
            return -1;

        if (this_minutes > other_minutes)
            return 1;

        return 0;
    }
}

private class Item : Object, ContentItem {
    public enum State {
        READY,
        RINGING,
        SNOOZING,
        MISSED
    }

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
    private GLib.DateTime? _ring_time;

    [CCode (notify = false)]
    public GLib.DateTime? ring_time {
        get {
            return _ring_time;
        }
        private set {
            if (value == _ring_time) {
                return;
            }

            var prev_active = active;
            _ring_time = value;

            if (prev_active != active) {
                notify_property ("active");
            }
            notify_property ("ring-time");
        }
    }

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

    private State _state = State.READY;

    [CCode (notify = false)]
    public State state {
        get {
            return _state;
        }
        private set {
            if (value == _state) {
                return;
            }

            var prev_state = _state;
            _state = value;

            if (prev_state == State.RINGING) {
                bell.stop ();
            }

            if (_state == State.RINGING) {
                ring ();
            }

            notify_property ("state");
        }
    }

    public string time_label {
         owned get {
            // FIXME: Format the time without creating GLib.DateTime
            var wallclock = Utils.WallClock.get_default ();
            var now = wallclock.date_time;
            var dt = new GLib.DateTime (wallclock.timezone,
                                        now.get_year (),
                                        now.get_month (),
                                        now.get_day_of_month (),
                                        time.hour,
                                        time.minute,
                                        0);

            return wallclock.format_time (dt, false);
         }
    }

    public string ring_time_label {
         owned get {
            return Utils.WallClock.get_default ().format_time (ring_time, false);
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
            return ring_time != null;
        }
        set {
            if (value == active) {
                return;
            }

            if (value) {
                ring_time = next_ring_time ();
            } else {
                ring_time = null;
            }

            state = State.READY;
        }
    }

    private string _name;
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
        ring_time = next_ring_time ();
        state = State.READY;
    }

    private GLib.DateTime next_ring_time () {
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

        return dt;
    }

    private void ring () {
        var app = (Clocks.Application) GLib.Application.get_default ();
        app.send_notification ("alarm-clock-elapsed", notification);
        bell.ring ();
    }

    public void snooze () {
        ring_time = ring_time.add_minutes (snooze_minutes);
        state = State.SNOOZING;
    }

    public void stop (bool missed = false) {
        // Disable the alarm if it doesn't have repeat days
        if (days == null || ((Utils.Weekdays) days).empty) {
            ring_time = null;
        } else {
            ring_time = next_ring_time ();
        }

        if (missed) {
            state = State.MISSED;
        } else {
            state = State.READY;
        }
    }

    private bool compare_with_item (Item i) {
        return (this.time.is_eq (i.time) && this.active && i.active);
    }

    public bool check_duplicate_alarm (List<Item> alarms) {
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

        var ring_end_time = ring_time.add_minutes (ring_minutes);

        if (now.compare (ring_end_time) > 0) {
            stop (true);
        } else if ((state != State.RINGING) && now.compare (ring_time) > 0) {
            state = State.RINGING;
        }

        return state != last_state;
    }

    public void serialize (GLib.VariantBuilder builder) {
        builder.open (new GLib.VariantType ("a{sv}"));
        builder.add ("{sv}", "name", new GLib.Variant.string ((string) name));
        builder.add ("{sv}", "id", new GLib.Variant.string (id));
        builder.add ("{sv}", "hour", new GLib.Variant.int32 (time.hour));
        builder.add ("{sv}", "minute", new GLib.Variant.int32 (time.minute));
        if (ring_time != null)
            builder.add ("{sv}", "ring_time", new GLib.Variant.string (((!) ring_time).format_iso8601 ()));
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
        bool active = false;
        int hour = -1;
        int minute = -1;
        GLib.DateTime? ring_time = null;
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
            } else if (key == "ring_time") {
                ring_time = new GLib.DateTime.from_iso8601 ((string) val, null);
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
            alarm.time = { hour, minute };
            // Keep compatibility with older versions
            if (active && ring_time == null) {
                alarm.active = true;
            } else {
                alarm.ring_time = ring_time;
            }
            alarm.days = days;
            alarm.ring_minutes = ring_minutes;
            alarm.snooze_minutes = snooze_minutes;
            return alarm;
        } else {
            warning ("Invalid alarm %s", name != null ? (string) name : "[unnamed]");
        }

        return null;
    }

    public static int compare (Item a, Item b) {
        return a.time.compare (b.time);
    }
}

} // namespace Alarm
} // namespace Clocks
