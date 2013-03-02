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
    // ringing but we keep showing the standalone?
    public enum State {
        READY,
        RINGING,
        SNOOZING
    }

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

    public Item () {
        days = new Utils.Weekdays ();
    }

    public Item.with_data (string name, bool active, int hour, int minute, Utils.Weekdays days) {
        Object (name: name, active: active, hour: hour, minute: minute, days: days);

        setup_bell ();
        reset ();
    }

    private void setup_bell () {
        bell = new Utils.Bell ("alarm-clock-elapsed", _("Alarm"), name);
        bell.add_action ("stop", _("Stop"), () => {
            stop ();
        });
        bell.add_action ("snooze", _("Snooze"), () => {
            snooze ();
        });
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

    public void get_thumb_properties (out string text, out string subtext, out Gdk.Pixbuf? pixbuf, out string css_class) {
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
        builder.add ("{sv}", "active", new GLib.Variant.boolean (active));
        builder.add ("{sv}", "hour", new GLib.Variant.int32 (hour));
        builder.add ("{sv}", "minute", new GLib.Variant.int32 (minute));
        builder.add ("{sv}", "days", days.serialize ());
        builder.close ();
    }

    public static Item? deserialize (GLib.Variant alarm_variant) {
        string? name = null;
        bool active = true;
        int hour = -1;
        int minute = -1;
        Utils.Weekdays days = new Utils.Weekdays ();
        foreach (var v in alarm_variant) {
            var key = v.get_child_value (0).get_string ();
            if (key == "name") {
                name = v.get_child_value (1).get_child_value (0).get_string ();
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
            return new Item.with_data (name, active, hour, minute, days);
        } else {
            warning ("Invalid alarm %s", name != null ? name : "name missing");
        }
        return null;
    }
}

private class SetupDialog : Gtk.Dialog {
    private Utils.WallClock.Format format;
    private Gtk.SpinButton h_spinbutton;
    private Gtk.SpinButton m_spinbutton;
    private Gtk.Entry name_entry;
    private AmPmToggleButton am_pm_button;
    private Gtk.ToggleButton[] day_buttons;
    private Gtk.Switch active_switch;

    public SetupDialog (Gtk.Window parent, Item? alarm) {
        Object (transient_for: parent, modal: true, title: alarm != null ? _("Edit Alarm") : _("New Alarm"));

        add_buttons (Gtk.Stock.CANCEL, 0, _("_Done"), 1);
        set_default_response (1);

        format  = Utils.WallClock.get_default ().format;
        am_pm_button = new AmPmToggleButton ();

        // Get objects from the ui file
        var builder = Utils.load_ui ("alarm.ui");
        var grid = builder.get_object ("setup_dialog_content") as Gtk.Grid;
        var am_pm_alignment = builder.get_object ("am_pm_alignment") as Gtk.Alignment;
        var am_pm_sizegroup = builder.get_object ("am_pm_sizegroup") as Gtk.SizeGroup;
        var day_buttons_box = builder.get_object ("day_buttons_box") as Gtk.Box;
        h_spinbutton = builder.get_object ("h_spinbutton") as Gtk.SpinButton;
        m_spinbutton = builder.get_object ("m_spinbutton") as Gtk.SpinButton;
        name_entry = builder.get_object ("name_entry") as Gtk.Entry;
        active_switch = builder.get_object ("active_switch") as Gtk.Switch;

        h_spinbutton.output.connect (show_leading_zeros);
        m_spinbutton.output.connect (show_leading_zeros);
        if (format == Utils.WallClock.Format.TWENTYFOUR)
            // 24h format
            h_spinbutton.set_range (0, 23);
        else {
            // 12h format
            h_spinbutton.set_range (1, 12);
            am_pm_sizegroup.add_widget (am_pm_button);
            am_pm_alignment.remove (am_pm_alignment.get_child ());
            am_pm_alignment.add (am_pm_button);
        }

        // Create an array with the weekday buttons with
        // day_buttons[0] referencing the button for Monday, and so on.
        day_buttons = new Gtk.ToggleButton[7];
        for (int i = 0; i < 7; i++) {
            var button = new Gtk.ToggleButton.with_label (Utils.Weekdays.abbreviation ((Utils.Weekdays.Day) i));
            day_buttons[i] = button;
        }

        // Pack the buttons, starting with the first day of the week
        // depending on the locale.
        var first_weekday = Utils.Weekdays.get_first_weekday ();
        for (int i = 0; i < 7; i++) {
            var day_number = (first_weekday + i) % 7;
            day_buttons_box.pack_start (day_buttons[day_number]);
        }

        get_content_area ().add (grid);
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

    private bool show_leading_zeros (Gtk.SpinButton spin_button) {
        spin_button.set_text ("%02i".printf (spin_button.get_value_as_int ()));
        return true;
    }
}

private class StandalonePanel : Gtk.EventBox {
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
    private Gtk.Label time_label;
    private Gtk.Button stop_button;
    private Gtk.Button snooze_button;

    public StandalonePanel () {
        get_style_context ().add_class ("view");
        get_style_context ().add_class ("content-view");

        var builder = Utils.load_ui ("alarm.ui");
        var grid = builder.get_object ("ringing_panel") as Gtk.Grid;
        time_label = builder.get_object ("time_label") as Gtk.Label;
        stop_button = builder.get_object ("stop_button") as Gtk.Button;
        snooze_button = builder.get_object ("snooze_button") as Gtk.Button;

        stop_button.clicked.connect (() => {
            alarm.stop ();
        });

        snooze_button.clicked.connect (() => {
            alarm.snooze ();
        });

        add (grid);
    }

    public virtual signal void dismiss () {
        alarm = null;
    }

    public void update () {
        if (alarm != null) {
            time_label.set_text (alarm.time_label);
        }
    }
}

public class MainPanel : Gd.Stack, Clocks.Clock {
    public string label { get; construct set; }
    public Toolbar toolbar { get; construct set; }

    private List<Item> alarms;
    private GLib.Settings settings;
    private ContentView content_view;
    private StandalonePanel standalone;

    public MainPanel (Toolbar toolbar) {
        Object (label: _("Alarm"), toolbar: toolbar);

        alarms = new List<Item> ();
        settings = new GLib.Settings("org.gnome.clocks");

        var builder = Utils.load_ui ("alarm.ui");
        var empty_view = builder.get_object ("empty_panel") as Gtk.Widget;
        content_view = new ContentView (empty_view, toolbar);
        add (content_view);

        content_view.item_activated.connect ((item) => {
            Item alarm = (Item) item;
            if (alarm.state == Item.State.SNOOZING) {
                show_ringing_panel (alarm);
            } else {
                edit (alarm);
            }
        });

        content_view.delete_selected.connect (() => {
            foreach (Object i in content_view.get_selected_items ()) {
                alarms.remove ((Item) i);
            }
            save ();
        });

        standalone = new StandalonePanel ();
        add (standalone);

        standalone.dismiss.connect (() => {
            visible_child = content_view;
        });

        load ();

        var id = notify["visible-child"].connect (() => {
            if (visible_child == content_view) {
                toolbar.mode = Toolbar.Mode.NORMAL;
            } else if (visible_child == standalone) {
                toolbar.mode = Toolbar.Mode.STANDALONE;
            }
        });
        toolbar.destroy.connect(() => {
            disconnect (id);
            id = 0;
        });

        visible_child = content_view;
        show_all ();

        // Start ticking...
        Utils.WallClock.get_default ().tick.connect (() => {
            foreach (var a in alarms) {
                // a.tick() returns true if the state changed
                if (a.tick()) {
                    if (a.state == Item.State.RINGING) {
                        show_ringing_panel (a);
                        ring ();
                    } else if (standalone.alarm == a) {
                        standalone.update ();
                    }
                }
            }
        });
    }

    public signal void ring ();

    private void load () {
        foreach (var a in settings.get_value ("alarms")) {
            Item? alarm = Item.deserialize (a);
            if (alarm != null) {
                alarms.prepend (alarm);
                content_view.add_item (alarm);
            }
        }
        alarms.reverse ();
    }

    private void save () {
        var builder = new GLib.VariantBuilder (new VariantType ("aa{sv}"));
        foreach (Item i in alarms) {
            i.serialize (builder);
        }
        settings.set_value ("alarms", builder.end ());
    }

    private void edit (Item alarm) {
        var dialog = new SetupDialog ((Gtk.Window) get_toplevel (), alarm);

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
        standalone.alarm = alarm;
        standalone.update ();
        visible_child = standalone;
    }

    public void activate_new () {
        var dialog = new SetupDialog ((Gtk.Window) get_toplevel (), null);
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

    public void update_toolbar () {
        switch (toolbar.mode) {
        case Toolbar.Mode.NORMAL:
            // Translators: "New" refers to an alarm
            var new_button = toolbar.add_button (null, _("New"), true);
            new_button.clicked.connect (() => {
                activate_new ();
            });
            content_view.update_toolbar ();
            break;
        case Toolbar.Mode.SELECTION:
            content_view.update_toolbar ();
            break;
        case Toolbar.Mode.STANDALONE:
            toolbar.set_labels_menu (null);
            toolbar.set_labels (GLib.Markup.escape_text (standalone.alarm.name), null);
            break;
        default:
            assert_not_reached ();
        }
    }
}

} // namespace Alarm
} // namespace Clocks
