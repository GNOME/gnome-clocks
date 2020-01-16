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

private struct AlarmTime {
    public int hour;
    public int minute;
}

private class Item : Object, ContentItem {
    const int SNOOZE_MINUTES = 9;
    const int RING_MINUTES = 3;

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

    public bool editing { get; set; default = false; }

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

    public AlarmTime time { get; set; }

    public Utils.Weekdays days { get; set; }

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

    public string days_label {
         owned get {
            return days != null ? days.get_label () : null;
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
                if (_active) {
                    reset ();
                } else if (state == State.RINGING) {
                    stop ();
                }
                notify_property ("active");
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

    public Item (string? id = null) {
        var guid = id != null ? id : GLib.DBus.generate_guid ();
        Object (id: guid);
    }

    private void setup_bell () {
        bell = new Utils.Bell ("alarm-clock-elapsed");
        notification = new GLib.Notification (_("Alarm"));
        notification.set_body (name);
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

        if (days == null || days.empty) {
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
        var app = GLib.Application.get_default () as Clocks.Application;
        app.send_notification ("alarm-clock-elapsed", notification);
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
        builder.add ("{sv}", "name", new GLib.Variant.string (name));
        builder.add ("{sv}", "id", new GLib.Variant.string (id));
        builder.add ("{sv}", "active", new GLib.Variant.boolean (active));
        builder.add ("{sv}", "hour", new GLib.Variant.int32 (time.hour));
        builder.add ("{sv}", "minute", new GLib.Variant.int32 (time.minute));
        builder.add ("{sv}", "days", days.serialize ());
        builder.close ();
    }

    public static ContentItem? deserialize (GLib.Variant alarm_variant) {
        string? name = null;
        string? id = null;
        bool active = true;
        int hour = -1;
        int minute = -1;
        Utils.Weekdays days = null;
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
            Item alarm = new Item (id);
            alarm.name = name;
            alarm.active = active;
            alarm.time = { hour, minute };
            alarm.days = days;
            alarm.reset ();
            return alarm;
        } else {
            warning ("Invalid alarm %s", name != null ? name : "name missing");
        }
        return null;
    }
}

[GtkTemplate (ui = "/org/gnome/clocks/ui/alarmrow.ui")]
private class Row : Gtk.ListBoxRow {
    public Item alarm { get; construct set; }
    public Face face { get; construct set; }

    [GtkChild]
    private Gtk.Switch toggle;
    [GtkChild]
    private Gtk.Label title;
    [GtkChild]
    private Gtk.Revealer title_reveal;
    [GtkChild]
    private Gtk.Label time;
    [GtkChild]
    private Gtk.Label repeats;
    [GtkChild]
    private Gtk.Revealer repeats_reveal;

    public Row (Item alarm, Face face) {
        Object (alarm: alarm, face: face);

        alarm.notify["days"].connect (update_repeats);

        alarm.bind_property ("active", toggle, "active", SYNC_CREATE | BIDIRECTIONAL);

        alarm.notify["name"].connect (update);
        alarm.notify["active"].connect (update);
        alarm.notify["state"].connect (update);
        alarm.notify["time"].connect (update);

        update_repeats ();
        update ();
    }

    private void update_repeats () {
        repeats_reveal.reveal_child = !alarm.days.empty;
        repeats.label = alarm.days_label;
    }

    private void update () {
        if (alarm.active) {
            get_style_context ().add_class ("active");
        } else {
            get_style_context ().remove_class ("active");
        }

        if (alarm.state == Item.State.SNOOZING) {
            get_style_context ().add_class ("snoozing");
            time.label = alarm.snooze_time_label;
        } else {
            get_style_context ().remove_class ("snoozing");
            time.label = alarm.time_label;
        }

        var label = alarm.name;

        // Prior to 3.36 unamed alarms would just be called "Alarm",
        // pretend alarms called "Alarm" don't have a name (of course
        // this fails if the language/translation has since changed)
        if (alarm.name == _("Alarm")) {
            label = null;
        }

        if (alarm.state == Item.State.SNOOZING) {
            if (label != null && label.length > 0) {
                label = "Snoozed from %s: %s".printf (alarm.time_label, label);
            } else {
                label = "Snoozed from %s".printf (alarm.time_label);
            }
        }

        title_reveal.reveal_child = label != null && label.length > 0;
        title.label = label;
    }

    [GtkCallback]
    private void edit () {
        face.edit (alarm);
    }

    [GtkCallback]
    private void delete () {
        face.delete (alarm);
    }
}

[GtkTemplate (ui = "/org/gnome/clocks/ui/alarmdaypickerrow.ui")]
public class DayPickerRow : Hdy.ActionRow {
    public bool monday {
        get {
            return days[Utils.Weekdays.Day.MON];
        }

        set {
            days[Utils.Weekdays.Day.MON] = value;
            update();
        }
    }

    public bool tuesday {
        get {
            return days[Utils.Weekdays.Day.TUE];
        }

        set {
            days[Utils.Weekdays.Day.TUE] = value;
            update();
        }
    }

    public bool wednesday {
        get {
            return days[Utils.Weekdays.Day.WED];
        }

        set {
            days[Utils.Weekdays.Day.WED] = value;
            update();
        }
    }

    public bool thursday {
        get {
            return days[Utils.Weekdays.Day.THU];
        }

        set {
            days[Utils.Weekdays.Day.THU] = value;
            update();
        }
    }

    public bool friday {
        get {
            return days[Utils.Weekdays.Day.FRI];
        }

        set {
            days[Utils.Weekdays.Day.FRI] = value;
            update();
        }
    }

    public bool saturday {
        get {
            return days[Utils.Weekdays.Day.SAT];
        }

        set {
            days[Utils.Weekdays.Day.SAT] = value;
            update();
        }
    }

    public bool sunday {
        get {
            return days[Utils.Weekdays.Day.SUN];
        }

        set {
            days[Utils.Weekdays.Day.SUN] = value;
            update();
        }
    }

    public signal void days_changed ();

    private Utils.Weekdays days = new Utils.Weekdays();

    [GtkChild]
    private Gtk.FlowBox flow;

    construct {
        // Create actions to control propeties from menu items
        var group = new SimpleActionGroup ();
        group.add_action (new PropertyAction ("day-0", this, "monday"));
        group.add_action (new PropertyAction ("day-1", this, "tuesday"));
        group.add_action (new PropertyAction ("day-2", this, "wednesday"));
        group.add_action (new PropertyAction ("day-3", this, "thursday"));
        group.add_action (new PropertyAction ("day-4", this, "friday"));
        group.add_action (new PropertyAction ("day-5", this, "saturday"));
        group.add_action (new PropertyAction ("day-6", this, "sunday"));
        insert_action_group ("repeats", group);

        // Create an array with the weekday items with
        // buttons[0] referencing the button for Monday, and so on.
        var buttons = new Gtk.ToggleButton[7];
        for (int i = 0; i < 7; i++) {
            var day = (Utils.Weekdays.Day) i;
            buttons[i] = new Gtk.ToggleButton.with_label (day.symbol ());
            buttons[i].action_name = "repeats.day-%i".printf(i);
            buttons[i].tooltip_text = day.name ();
            buttons[i].get_style_context ().add_class ("circular");
            buttons[i].show ();
        }

        // Add the items, starting with the first day of the week
        // depending on the locale.
        var first_weekday = Utils.Weekdays.Day.get_first_weekday ();
        for (int i = 0; i < 7; i++) {
            var day_number = (first_weekday + i) % 7;
            flow.add (buttons[day_number]);
        }

        update ();
    }

    public void load (Utils.Weekdays current_days) {
        // Copy in the days
        for (int i = 0; i < 7; i++) {
            days[(Utils.Weekdays.Day) i] = current_days[(Utils.Weekdays.Day) i];
        }

        // Make sure the buttons update
        notify_property ("monday");
        notify_property ("tuesday");
        notify_property ("wednesday");
        notify_property ("thursday");
        notify_property ("friday");
        notify_property ("saturday");
        notify_property ("sunday");

        update ();
    }

    public Utils.Weekdays store () {
        var new_days = new Utils.Weekdays ();

        for (int i = 0; i < 7; i++) {
            new_days[(Utils.Weekdays.Day) i] = days[(Utils.Weekdays.Day) i];
        }

        return new_days;
    }

    private void update () {
        days_changed ();
    }
}

[GtkTemplate (ui = "/org/gnome/clocks/ui/alarmsetupdialog.ui")]
private class SetupDialog : Hdy.Dialog {
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
    [GtkChild]
    private DayPickerRow repeats;
    [GtkChild]
    private Gtk.Stack am_pm_stack;
    [GtkChild]
    private Gtk.Revealer label_revealer;
    [GtkChild]
    private Gtk.ListBox listbox;
    [GtkChild]
    private Gtk.Button delete_button;
    private List<Item> other_alarms;

    static construct {
        typeof(DayPickerRow).ensure();
    }

    public SetupDialog (Gtk.Window parent, Item? alarm, ListModel all_alarms) {
        Object (transient_for: parent, title: alarm != null ? _("Edit Alarm") : _("New Alarm"), use_header_bar: 1);

        delete_button.visible = alarm != null;
        listbox.set_header_func((Gtk.ListBoxUpdateHeaderFunc) Hdy.list_box_separator_header);

        other_alarms = new List<Item> ();
        var n = all_alarms.get_n_items ();
        for (int i = 0; i < n; i++) {
            var item = all_alarms.get_object (i) as Item;
            if (alarm != item) {
                other_alarms.prepend (all_alarms.get_object (i) as Item);
            }
        }

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
            // Not great but we can't null it
            name = "";
            hour = wc.date_time.get_hour ();
            minute = wc.date_time.get_minute ();
            days = null;
            active = true;
        } else {
            name = alarm.name;
            hour = alarm.time.hour;
            minute = alarm.time.minute;
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

        if (days != null) {
            repeats.load (days);
        }
    }

    // Sets alarm according to the current dialog settings.
    public void apply_to_alarm (Item alarm) {
        var name = name_entry.get_text ();
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

        AlarmTime time = { hour, minute };

        var days = repeats.store ();

        alarm.freeze_notify ();

        alarm.name = name;
        alarm.time = time;
        alarm.days = days;

        // Force update of alarm_time before notifying the changes
        alarm.reset ();

        alarm.thaw_notify ();
    }

    private void avoid_duplicate_alarm () {
        var alarm = new Item ();
        apply_to_alarm (alarm);

        var duplicate = alarm.check_duplicate_alarm (other_alarms);
        this.set_response_sensitive (1, !duplicate);
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
        response (2);
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
    private Gtk.Label title_label;
    [GtkChild]
    private Gtk.Label time_label;

    [GtkCallback]
    private void stop_clicked () {
        alarm.stop ();
    }

    [GtkCallback]
    private void snooze_clicked () {
        if (alarm.state != Item.State.SNOOZING) {
            alarm.snooze ();
        } else {
            // The alarm is already snoozed, simply dismiss the panel.
            dismiss ();
        }
    }

    public virtual signal void dismiss () {
        alarm = null;
    }

    public void update () {
        if (alarm != null) {
            title_label.label = alarm.name;
            if (alarm.state == Item.State.SNOOZING) {
                time_label.label = alarm.snooze_time_label;
            } else {
                time_label.label = alarm.time_label;
            }
        } else {
            title_label.label = "";
            time_label.label = "";
        }
    }
}

[GtkTemplate (ui = "/org/gnome/clocks/ui/alarm.ui")]
public class Face : Gtk.Stack, Clocks.Clock {
    public ViewMode view_mode { get; set; default = NORMAL; }
    public PanelId panel_id { get; construct set; }
    public ButtonMode button_mode { get; set; default = NEW; }
    public bool can_select { get; set; default = false; }
    public bool n_selected { get; set; }
    public string title { get; set; default = _("Clocks"); }
    public string subtitle { get; set; }
    // Translators: Tooltip for the + button
    public string new_label { get; default = _("New Alarm"); }

    private ContentStore alarms;
    private GLib.Settings settings;
    [GtkChild]
    private Gtk.Widget empty_view;
    [GtkChild]
    private Gtk.ListBox listbox;
    [GtkChild]
    private Gtk.ScrolledWindow list_view;
    [GtkChild]
    private RingingPanel ringing_panel;

    construct {
        panel_id = ALARM;

        alarms = new ContentStore ();
        settings = new GLib.Settings ("org.gnome.clocks");

        var app = GLib.Application.get_default ();
        var action = app.lookup_action ("stop-alarm");
        ((GLib.SimpleAction)action).activate.connect ((action, param) => {
            var a = (Item)alarms.find ((a) => {
                return ((Item)a).id == param.get_string ();
            });
            if (a != null) {
                a.stop ();
            }
        });

        action = app.lookup_action ("snooze-alarm");
        ((GLib.SimpleAction)action).activate.connect ((action, param) => {
            var a = (Item)alarms.find ((a) => {
                return ((Item)a).id == param.get_string ();
            });
            if (a != null) {
                a.snooze ();
            }
        });

        listbox.set_header_func((Gtk.ListBoxUpdateHeaderFunc) Hdy.list_box_separator_header);
        listbox.bind_model (alarms, (item) => {
            return new Row ((Item) item, this);
        });

        load ();
        show_all ();

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
                        show_ringing_panel (a);
                        ring ();
                    } else if (ringing_panel.alarm == a) {
                        ringing_panel.update ();
                    }
                }
            });
        });
    }

    public signal void ring ();

    [GtkCallback]
    private void dismiss_ringing_panel () {
       reset_view ();
       button_mode = NEW;
       title = _("Clocks");
    }

    [GtkCallback]
    private void visible_child_changed () {
        if (visible_child == empty_view || visible_child == list_view) {
            view_mode = NORMAL;
        } else if (visible_child == ringing_panel) {
            view_mode = STANDALONE;
        }
    }

    private void load () {
        alarms.deserialize (settings.get_value ("alarms"), Item.deserialize);
    }

    private void save () {
        settings.set_value ("alarms", alarms.serialize ());
    }

    internal void edit (Item alarm) {
        var dialog = new SetupDialog ((Gtk.Window) get_toplevel (), alarm, alarms);

        // Disable alarm while editing it and remember the original active state.
        alarm.editing = true;

        dialog.response.connect ((dialog, response) => {
            alarm.editing = false;
            if (response == 1) {
                ((SetupDialog) dialog).apply_to_alarm (alarm);
                save ();
            } else if (response == 2) {
                alarms.delete_item (alarm);
                save ();
            }
            dialog.destroy ();
        });
        dialog.show ();
    }

    internal void delete (Item alarm) {
        alarms.delete_item (alarm);
        save ();
    }

    private void show_ringing_panel (Item alarm) {
        ringing_panel.alarm = alarm;
        ringing_panel.update ();
        visible_child = ringing_panel;
        title = _("Alarm");
        view_mode = STANDALONE;
        button_mode = NONE;
    }

    private void reset_view () {
        visible_child = alarms.get_n_items () == 0 ? empty_view : list_view;
    }

    public void activate_new () {
        var dialog = new SetupDialog ((Gtk.Window) get_toplevel (), null, alarms);
        dialog.response.connect ((dialog, response) => {
            if (response == 1) {
                var alarm = new Item ();
                ((SetupDialog) dialog).apply_to_alarm (alarm);
                alarms.add (alarm);
                save ();
            }
            dialog.destroy ();
        });
        dialog.show ();
    }

    public void activate_select () {
        view_mode = SELECTION;
    }

    public void activate_select_cancel () {
        view_mode = NORMAL;
    }

    public void activate_select_all () {
        // content_view.select_all ();
    }

    public void activate_select_none () {
        // content_view.unselect_all ();
    }

    public bool escape_pressed () {
        return /*content_view.escape_pressed ();*/ false;
    }
}

} // namespace Alarm
} // namespace Clocks
