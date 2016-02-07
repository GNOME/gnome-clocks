/*
 * Copyright (C) 2013  Paolo Borelli <pborelli@gnome.org>
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
    static const int SNOOZE_MINUTES = 9;
    static const int RING_MINUTES = 3;

    // FIXME: should we add a "MISSED" state where the alarm stopped
    // ringing but we keep showing the ringing panel?
    public enum State {
        READY,
        RINGING,
        SNOOZING
    }

    public string title_icon { get; set; default = null; }

    public bool selectable { get; set; default = true; }

    public bool selected { get; set; default = false; }

    public string id { get; construct set; }

    public string name {
        get {
            return _name;
        }

        set {
            _name = value;
            setup_bell ();
        }
    }

    public int hour { get; set; }
    public int minute { get; set; }
    public Utils.Weekdays days { get; construct set; }

    public string repeat_label {
        owned get {
            return days.get_label ();
        }
    }

    public State state { get; private set; }

    public string time_label {
         owned get {
            return Utils.WallClock.get_default ().format_time (alarm_time);
         }
    }

    public string snooze_time_label {
         owned get {
            return Utils.WallClock.get_default ().format_time (snooze_time);
         }
    }

    public bool active {
        get {
            return _active;
        }

        set {
            if (value != _active) {
                _active = value;
                if (_active) {
                    reset ();
                } else if (state == State.RINGING) {
                    stop ();
                }
            }
        }
    }

    private string _name;
    private bool _active;
    private GLib.DateTime alarm_time;
    private GLib.DateTime snooze_time;
    private GLib.DateTime ring_end_time;
    private Utils.Bell bell;
    private GLib.Notification notification;

    public Item () {
        id = GLib.DBus.generate_guid ();
        days = new Utils.Weekdays ();
    }

    public Item.with_data (string? id, string name, bool active, int hour, int minute, Utils.Weekdays days) {
        var _id = id != null ? id : GLib.DBus.generate_guid();
        Object (id: _id, name: name, active: active, hour: hour, minute: minute, days: days);

        setup_bell ();
        reset ();
    }

    private void setup_bell () {
        bell = new Utils.Bell ("alarm-clock-elapsed");
        notification = new GLib.Notification (_("Alarm"));
        notification.set_body (name);
        notification.add_button (_("Stop"), "app.stop-alarm::".concat(id));
        notification.add_button (_("Snooze"), "app.snooze-alarm::".concat(id));
    }

    public void reset () {
        update_alarm_time ();
        update_snooze_time (alarm_time);
        state = State.READY;
    }

    private void update_alarm_time () {
        var wallclock = Utils.WallClock.get_default ();
        var now = wallclock.date_time;
        var dt = new GLib.DateTime(wallclock.timezone,
                                   now.get_year (),
                                   now.get_month (),
                                   now.get_day_of_month (),
                                   hour,
                                   minute,
                                   0);

        if (days.empty) {
            // Alarm without days.
            if (dt.compare (now) <= 0) {
                // Time already passed, ring tomorrow.
                dt = dt.add_days (1);
            }
        } else {
            // Alarm with at least one day set.
            // Find the next possible day for ringing
            while (dt.compare (now) <= 0 || ! days.get ((Utils.Weekdays.Day) (dt.get_day_of_week () -1))) {
                dt = dt.add_days (1);
            }
        }

        alarm_time = dt;
    }

    private void update_snooze_time (GLib.DateTime start_time) {
        snooze_time = start_time.add_minutes (SNOOZE_MINUTES);
    }

    public virtual signal void ring () {
        var app = GLib.Application.get_default ();
        app.send_notification (null, notification);
        bell.ring ();
    }

    private void start_ringing (GLib.DateTime now) {
        update_snooze_time (now);
        ring_end_time = now.add_minutes (RING_MINUTES);
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
        return (this.alarm_time.compare (i.alarm_time) == 0 && this.active && i.active);
    }

    public bool check_duplicate_alarm (ListModel alarms) {
        update_alarm_time ();

        var n = alarms.get_n_items ();
        for (int i = 0; i < n; i++) {
            if (compare_with_item (alarms.get_object (i) as Item)) {
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

    public void get_thumb_properties (out string text,
                                      out string subtext,
                                      out Gdk.Pixbuf? pixbuf,
                                      out string css_class) {
        if (state == State.SNOOZING) {
            text = snooze_time_label;
            subtext = "(%s)".printf(time_label);
            css_class = "snoozing";
        } else {
            text = time_label;
            subtext = repeat_label;
            css_class = active ? "active" : "inactive";
        }
        pixbuf = null;
    }

    public void serialize (GLib.VariantBuilder builder) {
        builder.open (new GLib.VariantType ("a{sv}"));
        builder.add ("{sv}", "name", new GLib.Variant.string (name));
        builder.add ("{sv}", "id", new GLib.Variant.string (id));
        builder.add ("{sv}", "active", new GLib.Variant.boolean (active));
        builder.add ("{sv}", "hour", new GLib.Variant.int32 (hour));
        builder.add ("{sv}", "minute", new GLib.Variant.int32 (minute));
        builder.add ("{sv}", "days", days.serialize ());
        builder.close ();
    }

    public static Item? deserialize (GLib.Variant alarm_variant) {
        string? name = null;
        string? id = null;
        bool active = true;
        int hour = -1;
        int minute = -1;
        Utils.Weekdays days = new Utils.Weekdays ();
        foreach (var v in alarm_variant) {
            var key = v.get_child_value (0).get_string ();
            if (key == "name") {
                name = v.get_child_value (1).get_child_value (0).get_string ();
            } else if (key == "id") {
                id = v.get_child_value (1).get_child_value (0).get_string ();
            } else if (key == "active") {
                active = v.get_child_value (1).get_child_value (0).get_boolean ();
            } else if (key == "hour") {
                hour = v.get_child_value (1).get_child_value (0).get_int32 ();
            } else if (key == "minute") {
                minute = v.get_child_value (1).get_child_value (0).get_int32 ();
            } else if (key == "days") {
                days = Utils.Weekdays.deserialize (v.get_child_value (1).get_child_value (0));
            }
        }
        if (name != null && hour >= 0 && minute >= 0) {
            return new Item.with_data (id, name, active, hour, minute, days);
        } else {
            warning ("Invalid alarm %s", name != null ? name : "name missing");
        }
        return null;
    }
}

[GtkTemplate (ui = "/org/gnome/clocks/ui/alarmsetupdialog.ui")]
private class SetupDialog : Gtk.Dialog {
    private Utils.WallClock.Format format;
    [GtkChild]
    private Gtk.Grid time_grid;
    [GtkChild]
    private Gtk.SpinButton h_spinbutton;
    [GtkChild]
    private Gtk.SpinButton m_spinbutton;
    [GtkChild]
    private Gtk.Entry name_entry;
    private AmPmToggleButton am_pm_button;
    private Gtk.ToggleButton[] day_buttons;
    [GtkChild]
    private Gtk.Switch active_switch;
    [GtkChild]
    private Gtk.Box day_buttons_box;
    [GtkChild]
    private Gtk.Stack am_pm_stack;
    [GtkChild]
    private Gtk.Revealer label_revealer;
    private ListModel alarms;

    public SetupDialog (Gtk.Window parent, Item? alarm, ListModel all_alarms) {
        Object (transient_for: parent, title: alarm != null ? _("Edit Alarm") : _("New Alarm"), use_header_bar: 1);

        alarms = all_alarms;

        // Force LTR since we do not want to reverse [hh] : [mm]
        time_grid.set_direction (Gtk.TextDirection.LTR);

        // Create an array with the weekday buttons with
        // day_buttons[0] referencing the button for Monday, and so on.
        // Also declare toogled signal connection.
        day_buttons = new Gtk.ToggleButton[7];
        for (int i = 0; i < 7; i++) {
            var button = new Gtk.ToggleButton.with_label (Utils.Weekdays.abbreviation ((Utils.Weekdays.Day) i));
            day_buttons[i] = button;

            day_buttons[i].toggled.connect (() => {
                avoid_duplicate_alarm ();
            });
        }

        // Pack the buttons, starting with the first day of the week
        // depending on the locale.
        var first_weekday = Utils.Weekdays.get_first_weekday ();
        for (int i = 0; i < 7; i++) {
            var day_number = (first_weekday + i) % 7;
            day_buttons_box.pack_start (day_buttons[day_number]);
        }

        format  = Utils.WallClock.get_default ().format;
        am_pm_button = new AmPmToggleButton ();

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

        set_from_alarm (alarm);
    }

    // Sets up the dialog to show the values of alarm.
    public void set_from_alarm (Item? alarm) {
        string name;
        bool active;
        int hour;
        int minute;
        unowned Utils.Weekdays? days;

        if (alarm == null) {
            var wc = Utils.WallClock.get_default ();
            name = _("Alarm");
            hour = wc.date_time.get_hour();
            minute = wc.date_time.get_minute();
            days = null;
            active = true;
        } else {
            name = alarm.name;
            hour = alarm.hour;
            minute = alarm.minute;
            days = alarm.days;
            active = alarm.active;
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
        h_spinbutton.set_value (hour);
        m_spinbutton.set_value (minute);

        // Set the name.
        name_entry.set_text (name);

        // Set the toggle buttons for weekdays.
        if (days != null) {
            for (int i = 0; i < 7; i++) {
                day_buttons[i].active = days.get ((Utils.Weekdays.Day) i);
            }
        }

        // Set On/Off switch.
        active_switch.active = active;
    }

    // Sets alarm according to the current dialog settings.
    public void apply_to_alarm (Item alarm) {
        var name = name_entry.get_text();
        var active = active_switch.active;
        var hour = h_spinbutton.get_value_as_int ();
        var minute = m_spinbutton.get_value_as_int ();
        if (format == Utils.WallClock.Format.TWELVE) {
            var choice = am_pm_button.choice;
            if (choice == AmPmToggleButton.AmPm.AM && hour == 12) {
                hour = 0;
            } else if (choice == AmPmToggleButton.AmPm.PM && hour != 12) {
                hour += 12;
            }
        }

        alarm.name = name;
        alarm.active = active;
        alarm.hour = hour;
        alarm.minute = minute;

        for (int i = 0; i < 7; i++) {
            alarm.days.set ((Utils.Weekdays.Day) i, day_buttons[i].active);
        }
    }

    private void avoid_duplicate_alarm () {
        var alarm = new Item ();
        apply_to_alarm (alarm);

        if (alarm.check_duplicate_alarm (alarms)) {
            this.set_response_sensitive (1, false);
            label_revealer.set_reveal_child (true);
        } else {
            this.set_response_sensitive (1, true);
            label_revealer.set_reveal_child (false);
        }
    }

    [GtkCallback]
    private void spinbuttons_changed (Gtk.SpinButton spin_button) {
        avoid_duplicate_alarm ();
    }

    [GtkCallback]
    private void active_changed () {
        avoid_duplicate_alarm ();
    }

    [GtkCallback]
    private bool show_leading_zeros (Gtk.SpinButton spin_button) {
        spin_button.set_text ("%02i".printf (spin_button.get_value_as_int ()));
        return true;
    }
}

[GtkTemplate (ui = "/org/gnome/clocks/ui/alarmringing.ui")]
private class RingingPanel : Gtk.Grid {
    public Item alarm {
        get {
            return _alarm;
        }
        set {
            if (_alarm != null) {
                _alarm.disconnect (alarm_state_handler);
            }

            _alarm = value;

            if (_alarm != null) {
                alarm_state_handler = _alarm.notify["state"].connect (() => {
                    if (alarm.state != Item.State.RINGING) {
                        dismiss ();
                    }
                });
            }
        }
    }

    private Item? _alarm;
    private ulong alarm_state_handler;
    [GtkChild]
    private Gtk.Label time_label;

    [GtkCallback]
    private void stop_clicked () {
        alarm.stop ();
    }

    [GtkCallback]
    private void snooze_clicked () {
        alarm.snooze ();
    }

    public virtual signal void dismiss () {
        alarm = null;
    }

    public void update () {
        if (alarm != null) {
            if (alarm.state == Item.State.SNOOZING) {
                time_label.set_text (alarm.snooze_time_label);
            } else {
                time_label.set_text (alarm.time_label);
            }
        }
    }
}

[GtkTemplate (ui = "/org/gnome/clocks/ui/alarm.ui")]
public class Face : Gtk.Stack, Clocks.Clock {
    public string label { get; construct set; }
    public HeaderBar header_bar { get; construct set; }
    public PanelId panel_id { get; construct set; }

    private ListStore alarms;
    private GLib.Settings settings;
    private Gtk.Button new_button;
    [GtkChild]
    private ContentView content_view;
    [GtkChild]
    private Gtk.Widget empty_view;
    [GtkChild]
    private RingingPanel ringing_panel;

    public Face (HeaderBar header_bar) {
        Object (label: _("Alarm"),
                header_bar: header_bar,
                panel_id: PanelId.ALARM);

        alarms = new ListStore (typeof (Item));
        settings = new GLib.Settings ("org.gnome.clocks");

        var app = GLib.Application.get_default();
        var action = app.lookup_action ("stop-alarm");
        ((GLib.SimpleAction)action).activate.connect ((action, param) => {
            var item = find_item (param.get_string());
            if (item != null) {
                item.stop();
            }
        });

        action = app.lookup_action ("snooze-alarm");
        ((GLib.SimpleAction)action).activate.connect ((action, param) => {
            var item = find_item (param.get_string());
            if (item != null) {
                item.snooze();
            }
        });

        // Translators: "New" refers to an alarm
        new_button = new Gtk.Button.with_label (_("New"));
        new_button.valign = Gtk.Align.CENTER;
        new_button.no_show_all = true;
        new_button.action_name = "win.new";
        header_bar.pack_start (new_button);

        content_view.set_header_bar (header_bar);

        load ();
        reset_view ();
        show_all ();

        // Start ticking...
        Utils.WallClock.get_default ().tick.connect (() => {
            var n = alarms.get_n_items ();
            for (int i = 0; i < n; i++) {
                var a = alarms.get_object (i) as Item;
                // a.tick() returns true if the state changed
                if (a.tick()) {
                    if (a.state == Item.State.RINGING) {
                        show_ringing_panel (a);
                        ring ();
                    } else if (ringing_panel.alarm == a) {
                        ringing_panel.update ();
                    }
                }
            }
        });
    }

    public signal void ring ();

    [GtkCallback]
    private void item_activated (ContentItem item) {
        Item alarm = (Item) item;
        if (alarm.state == Item.State.SNOOZING) {
            show_ringing_panel (alarm);
        } else {
            edit (alarm);
        }
    }

    [GtkCallback]
    private void delete_selected () {
        Object[] not_selected = {};
        var n = alarms.get_n_items ();
        for (int i = 0; i < n; i++) {
            var o = alarms.get_object (i);
            if (!((Item)o).selected) {
                not_selected += o;
            }
        }
        // remove everything and readd the ones not selected
        alarms.splice(0, n, not_selected);
        save ();
    }

    [GtkCallback]
    private void empty_changed () {
        reset_view ();
    }

    [GtkCallback]
    private void dismiss_ringing_panel () {
       reset_view ();
    }

    [GtkCallback]
    private void visible_child_changed () {
        if (visible_child == empty_view || visible_child == content_view) {
            header_bar.mode = HeaderBar.Mode.NORMAL;
        } else if (visible_child == ringing_panel) {
            header_bar.mode = HeaderBar.Mode.STANDALONE;
        }
    }

    private Item? find_item (string id) {
        var n = alarms.get_n_items ();
        for (int i = 0; i < n; i++) {
            var item = alarms.get_object (i) as Item;
            if (item.id == id) {
                return item;
            }
        }
        return null;
    }

    private void load () {
        foreach (var a in settings.get_value ("alarms")) {
            Item? alarm = Item.deserialize (a);
            if (alarm != null) {
                alarms.append (alarm);
                content_view.add_item (alarm);
            }
        }
    }

    private void save () {
        var builder = new GLib.VariantBuilder (new VariantType ("aa{sv}"));
        var n = alarms.get_n_items ();
        for (int i = 0; i < n; i++) {
            var a = alarms.get_object (i) as Item;
            a.serialize (builder);
        }
        settings.set_value ("alarms", builder.end ());
    }

    private void edit (Item alarm) {
        var dialog = new SetupDialog ((Gtk.Window) get_toplevel (), alarm, alarms);

        // Disable alarm while editing it and remember the original active state.
        var saved_active = alarm.active;
        alarm.active = false;

        dialog.response.connect ((dialog, response) => {
            if (response == 1) {
                ((SetupDialog) dialog).apply_to_alarm (alarm);
                alarm.reset ();
                save ();
            } else {
                alarm.active = saved_active;
            }
            dialog.destroy ();
        });
        dialog.show_all ();
    }

    private void show_ringing_panel (Item alarm) {
        ringing_panel.alarm = alarm;
        ringing_panel.update ();
        visible_child = ringing_panel;
    }

    private void reset_view () {
        visible_child = content_view.empty ? empty_view : content_view;
    }

    public void activate_new () {
        var dialog = new SetupDialog ((Gtk.Window) get_toplevel (), null, alarms);
        dialog.response.connect ((dialog, response) => {
            if (response == 1) {
                var alarm = new Item ();
                ((SetupDialog) dialog).apply_to_alarm (alarm);
                alarms.append (alarm);
                content_view.add_item (alarm);
                alarm.reset();
                save ();
            }
            dialog.destroy ();
        });
        dialog.show_all ();
    }

    public void activate_select_all () {
        content_view.select_all ();
    }

    public void activate_select_none () {
        content_view.unselect_all ();
    }

    public bool escape_pressed () {
        return content_view.escape_pressed ();
    }

    public void update_header_bar () {
        switch (header_bar.mode) {
        case HeaderBar.Mode.NORMAL:
            new_button.show ();
            content_view.update_header_bar ();
            break;
        case HeaderBar.Mode.SELECTION:
            content_view.update_header_bar ();
            break;
        case HeaderBar.Mode.STANDALONE:
            header_bar.title = GLib.Markup.escape_text (ringing_panel.alarm.name);
            break;
        default:
            assert_not_reached ();
        }
    }
}

} // namespace Alarm
} // namespace Clocks
