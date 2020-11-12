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

private class Item : Object, ContentItem {
    public enum State {
        DISABLED,
        READY,
        RINGING,
        SNOOZING
    }

    // Missed can't be a state because we couldn't scheduale next alarms without override missed
    public bool missed { get; set; default = false; }

    public string id { get; construct set; }

    public int snooze_minutes { get; set; default = 10; }

    public int ring_minutes { get; set; default = 5; }

    public bool recurring {
        get {
            return days != null && !((!) days).empty;
        }
    }

    public string? name {
        get {
            return _name;
        }

        set {
            _name = (string) value;
            setup_bell ();
        }
    }

    public Utils.Weekdays? days { get; set; }

    private State _state = State.DISABLED;
    public State state {
        get {
            return _state;
        }
        private set {
            if (_state == value)
                return;

            _state = value;
            notify_property ("active");
        }
    }

    public string time_label {
         owned get {
            return Utils.WallClock.get_default ().format_time (time);
         }
    }

    public string snooze_time_label {
         owned get {
            if (snooze_time == null)
                return Utils.WallClock.get_default ().format_time (time.add_minutes (snooze_minutes));
            else
                return Utils.WallClock.get_default ().format_time ((!) snooze_time);
         }
    }

    public string? days_label {
         owned get {
            return days != null ? (string?) ((Utils.Weekdays) days).get_label () : null;
         }
    }

    public GLib.DateTime time { get; set; }

    [CCode (notify = false)]
    public bool active {
        get {
            return this.state > State.DISABLED;
        }
        set {
            if (this.state != State.DISABLED && !value) {
                stop ();
                this.state = State.DISABLED;
                notify_property ("active");
            } else if (this.state == State.DISABLED && value) {
                this.missed = false;
                this.time = get_next_alarm_time (time.get_hour (), time.get_minute (), days);
                this.state = State.READY;
                notify_property ("active");
            }
        }
    }

    private string _name;
    private GLib.DateTime? snooze_time;
    private Utils.Bell bell;
    private GLib.Notification notification;

    public Item (int hour, int minute, Utils.Weekdays? days = null, string? id = null) {
        var guid = id != null ? (string) id : GLib.DBus.generate_guid ();
        var time = get_next_alarm_time (hour, minute, days);
        Object (id: guid,
                time: time,
                days: days);
    }

    public Item.for_specific_time (GLib.DateTime time, Utils.Weekdays? days = null, string? id = null) {
        var guid = id != null ? (string) id : GLib.DBus.generate_guid ();
        Object (id: guid,
                time: time,
                days: days);
    }

    public void save_to_systemd (SystemdUtils.Timer systemd_timer) {
        var wallclock = Utils.WallClock.get_default ();
        var now = wallclock.date_time;
        if (snooze_time != null) {
            // Add timer only if the snooze time is in the future
            if (this.active && now.compare ((!) snooze_time) <= 0) {
                systemd_timer.add_time (((!) snooze_time).get_hour (),
                                        ((!) snooze_time).get_minute ());
            }
        }

        // Add the timer only if the alarm needs to go off in the future
        if (this.active && (now.compare (time) <= 0 || recurring)) {
            systemd_timer.add_time (time.get_hour (),
                                    time.get_minute (),
                                    days);
        }
    }

    private void setup_bell () {
        bell = new Utils.Bell ("alarm-clock-elapsed");
        notification = new GLib.Notification (_("Alarm"));
        notification.set_body (name);
        notification.add_button (_("Stop"), "app.stop-alarm::".concat (id));
        notification.add_button (_("Snooze"), "app.snooze-alarm::".concat (id));
    }

    public void set_alarm_time (int hour, int minute, Utils.Weekdays? days) {
      this.days = days;
      this.time = get_next_alarm_time (hour, minute, days);
    }

    private static GLib.DateTime get_next_alarm_time (int hour, int minute, Utils.Weekdays? days) {
        var wallclock = Utils.WallClock.get_default ();
        var now = wallclock.date_time;
        var dt = new GLib.DateTime (wallclock.timezone,
                                    now.get_year (),
                                    now.get_month (),
                                    now.get_day_of_month (),
                                    hour,
                                    minute,
                                    0);

        if (days == null || ((!) days).empty) {
            // Alarm without days.
            if (dt.compare (now) <= 0) {
                // Time already passed, ring tomorrow.
                dt = dt.add_days (1);
            }
        } else {
            // Alarm with at least one day set.
            // Find the next possible day for ringing
            while (dt.compare (now) <= 0 ||
                   ! ((Utils.Weekdays) days).get ((Utils.Weekdays.Day) (dt.get_day_of_week () - 1))) {
                dt = dt.add_days (1);
            }
        }

        return dt;
    }

    public virtual signal void ring () {
        var app = (Clocks.Application) GLib.Application.get_default ();
        app.send_notification ("alarm-clock-elapsed", notification);
        bell.ring ();
    }

    private void start_ringing (GLib.DateTime now) {
        state = State.RINGING;
        ring ();
    }

    public void snooze () {
        bell.stop ();
        if (snooze_time == null)
            snooze_time = time.add_minutes (snooze_minutes);
        else
            snooze_time = ((!) snooze_time).add_minutes (snooze_minutes);

        state = State.SNOOZING;
    }

    public void stop () {
        bell.stop ();
        snooze_time = null;

        // scheduale the next alarm if recurring
        if (recurring) {
            time = get_next_alarm_time (time.get_hour (), time.get_minute (), days);
            state = State.READY;
            GLib.Timeout.add_seconds (120, () => {
                missed = false;
                return GLib.Source.REMOVE;
            });
        } else {
            state = State.DISABLED;
        }
    }

    private bool compare_with_item (Item i) {
        return (this.time.get_hour () == i.time.get_hour () &&
                this.time.get_minute () == i.time.get_minute ());
    }

    public bool check_duplicate_alarm (List<Item> alarms) {
        foreach (var item in alarms) {
            if (this.compare_with_item (item)) {
                return true;
            }
        }
        return false;
    }

    private void start_ringing_or_missed (GLib.DateTime now, GLib.DateTime ring_end_time) {
        if (now.compare (ring_end_time) > 0 ) {
            missed = true;
            stop ();
        } else {
            start_ringing (now);
        }
    }

    // Update the state and ringing time. Ring or stop
    // depending on the current time.
    // Returns true if the state changed, false otherwise.
    public bool tick () {
        if (state == State.DISABLED) {
            return false;
        }

        State last_state = state;

        var wallclock = Utils.WallClock.get_default ();
        var now = wallclock.date_time;

        GLib.DateTime ring_end_time = (snooze_time != null) ?
            ( (!) snooze_time).add_minutes (ring_minutes) : time.add_minutes (ring_minutes);

        switch (state) {
            case State.DISABLED:
                break;
            case State.RINGING:
                // make sure the state changes
                last_state = State.READY;
                start_ringing_or_missed (now, ring_end_time);
                break;
            case State.SNOOZING:
                if (snooze_time != null && now.compare ((!) snooze_time) > 0)
                    start_ringing_or_missed (now, ring_end_time);
                break;
            case State.READY:
                if (now.compare (time) > 0)
                    start_ringing_or_missed (now, ring_end_time);
                break;
        }

        return state != last_state;
    }

    public void serialize (GLib.VariantBuilder builder) {
        builder.open (new GLib.VariantType ("a{sv}"));
        builder.add ("{sv}", "name", new GLib.Variant.string ((string) name));
        builder.add ("{sv}", "id", new GLib.Variant.string (id));
        builder.add ("{sv}", "state", new GLib.Variant.int32 (state));
        builder.add ("{sv}", "time", new GLib.Variant.string (time.format_iso8601 ()));
        if (snooze_time != null)
            builder.add ("{sv}", "snooze_time", new GLib.Variant.string (((!) snooze_time).format_iso8601 ()));
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
        State state = State.DISABLED;
        GLib.DateTime? time = null;
        GLib.DateTime? snooze_time = null;
        int snooze_minutes = 10;
        int ring_minutes = 5;
        Utils.Weekdays? days = null;

        var iter = alarm_variant.iterator ();
        while (iter.next ("{sv}", out key, out val)) {
            if (key == "name") {
                name = (string) val;
            } else if (key == "id") {
                id = (string) val;
            } else if (key == "state") {
                state = (State) val;
            } else if (key == "time") {
                time = new GLib.DateTime.from_iso8601 ((string) val, null);
            } else if (key == "snooze_time") {
                snooze_time = new GLib.DateTime.from_iso8601 ((string) val, null);
            } else if (key == "days") {
                days = Utils.Weekdays.deserialize (val);
            } else if (key == "snooze_minutes") {
                snooze_minutes = (int32) val;
            } else if (key == "ring_minutes") {
                ring_minutes = (int32) val;
            }
        }

        if (time != null) {
            Item alarm = new Item.for_specific_time ((!) time, days, id);
            alarm.state = state;
            alarm.name = name;
            if (snooze_time != null)
                alarm.snooze_time = (!) snooze_time;
            alarm.ring_minutes = ring_minutes;
            alarm.snooze_minutes = snooze_minutes;
            return alarm;
        } else {
            warning ("Invalid alarm %s", name != null ? (string) name : "[unnamed]");
        }

        return null;
    }
}

} // namespace Alarm
} // namespace Clocks
