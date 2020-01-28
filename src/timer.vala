/*
 * Copyright (C) 2013  Paolo Borelli <pborelli@gnome.org>
 * Copyright (C) 2020  Bilal Elmoussaoui <bilal.elmoussaoui@gnome.org>
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
namespace Timer {

public class Duration: Object {
    public int hours { get; set; default = 0; }
    public int minutes { get; set; default = 0; }
    public int seconds { get; set; default = 0; }

    public Duration.from_seconds (int s) {
        int rest = 0;
        hours = s / 3600;
        rest = s - hours * 3600;
        minutes = rest / 60;
        seconds = rest - minutes * 60;
    }

    public Duration (int h, int m, int s) {
        hours = h;
        minutes = m;
        seconds = s;
    }

    public int get_total_seconds () {
        return hours * 3600 + minutes * 60 + seconds;
    }
}


public class Item : Object, ContentItem {
    public bool selectable { get; set; default = false; }
    public bool selected { get; set; default = false; }

    public string name { get ; set; }
    public Duration duration { get; set; }

    public void serialize (GLib.VariantBuilder builder) {
        builder.open (new GLib.VariantType ("a{sv}"));
        builder.add ("{sv}", "duration", new GLib.Variant.int32 (duration.get_total_seconds ()));
        if (name != null) {
            builder.add ("{sv}", "name", new GLib.Variant.string (name));
        }
        builder.close ();
    }

    public static Item? deserialize (GLib.Variant time_variant) {
        Duration? duration = null;
        string? name = null;

        foreach (var v in time_variant) {
            var key = v.get_child_value (0).get_string ();
            switch (key) {
                case "duration":
                    duration = new Duration.from_seconds (v.get_child_value (1).get_child_value (0).get_int32());
                    break;
                case "name":
                    name = v.get_child_value (1).get_child_value (0).get_string ();
                    break;
            }
        }
        return duration != null ? new Item (duration, name) : null;
    }

    public Item (Duration duration, string? name) {
        Object (name: name, duration: duration);
    }
}


public class NewTimerDialog: Hdy.Dialog {
    public Setup timer_setup;

    public NewTimerDialog (Gtk.Window parent) {
        Object (transient_for: parent, title: _("New Timer"), use_header_bar: 1);
        this.set_default_size (640, 360);

        add_button (_("Cancel"), Gtk.ResponseType.CANCEL);
        var create_button = add_button (_("Add"), Gtk.ResponseType.ACCEPT);
        create_button.get_style_context ().add_class ("suggested-action");

        timer_setup = new Setup ();
        this.get_content_area ().add (timer_setup);
        timer_setup.duration_changed.connect ((duration) => {
            this.set_response_sensitive (Gtk.ResponseType.ACCEPT, duration.get_total_seconds () != 0);
        });
    }
}


[GtkTemplate (ui = "/org/gnome/clocks/ui/timer_setup.ui")]
public class Setup : Gtk.Box {
    public signal void duration_changed (Duration duration);
    [GtkChild]
    private Gtk.SpinButton h_spinbutton;
    [GtkChild]
    private Gtk.SpinButton m_spinbutton;
    [GtkChild]
    private Gtk.SpinButton s_spinbutton;

    public Setup () {
        var actions = new SimpleActionGroup ();
        // The duration here represends a number of minutes
        var duration_type = new GLib.VariantType ("i");
        var set_duration_action = new SimpleAction ("set-duration", duration_type);
        set_duration_action.activate.connect ((action, param) => {
            var total_minutes = param.get_int32 ();
            var hours = total_minutes / 60;
            var minutes = total_minutes - hours * 60;
            this.h_spinbutton.set_value (hours);
            this.m_spinbutton.set_value (minutes);
        });
        actions.add_action (set_duration_action);
        insert_action_group ("timer-setup", actions);

    }

    public Duration get_duration () {
        int h = (int)this.h_spinbutton.get_value ();
        int m = (int)this.m_spinbutton.get_value ();
        int s = (int)this.s_spinbutton.get_value ();

        var duration = new Duration (h, m, s);
        return duration;
    }

    public Item get_timer () {
        return (new Item (get_duration (), ""));
    }

    [GtkCallback]
    private void update_duration () {
        var duration = get_duration ();
        duration_changed (duration);
    }

    [GtkCallback]
    private bool show_leading_zeros (Gtk.SpinButton spin_button) {
        spin_button.set_text ("%02i".printf (spin_button.get_value_as_int ()));
        return true;
    }

    [GtkCallback]
    private int input_minutes (Gtk.SpinButton spin_button, out double new_value) {
        int entered_value = int.parse (spin_button.get_text ());

        // if input entered is not within bounds then it will carry the
        // extra portion to hours field
        if (entered_value > 59) {
           int current_hours = h_spinbutton.get_value_as_int ();
           h_spinbutton.set_value (double.min (99, current_hours + entered_value / 60));
        }
        new_value = entered_value % 60;
        return 1;
    }


    [GtkCallback]
    private int input_seconds (Gtk.SpinButton spin_button, out double new_value) {
        int entered_value = int.parse (spin_button.get_text ());

        // if input entered is not within bounds then it will carry the
        // extra portion to minutes field and hours field accordingly
        if (entered_value > 59) {
            int current_minutes = m_spinbutton.get_value_as_int ();
            int new_minutes = current_minutes + entered_value / 60;
            if (new_minutes > 59) {
                int current_hours = h_spinbutton.get_value_as_int ();
                h_spinbutton.set_value (double.min (99, current_hours + new_minutes / 60));
                new_minutes = new_minutes % 60;
            }
            m_spinbutton.set_value (new_minutes);

        }
        new_value = entered_value % 60;
        return 1;
    }
}


[GtkTemplate (ui = "/org/gnome/clocks/ui/timer_row.ui")]
public class Row : Gtk.ListBoxRow {
    public enum State {
        STOPPED,
        RUNNING,
        PAUSED
    }

    public State state { get; private set; default = State.STOPPED; }
    public Item item {
        get {
            return _item;
        }

        construct set {
            _item = value;

            title.text = _item.name;
            title.bind_property ("text", _item, "name");

            _item.notify["name"].connect (() => edited ());
        }
    }
    private Item _item = null;

    private double span;
    private GLib.Timer timer;
    private uint timeout_id;
    [GtkChild]
    private Gtk.Label countdown_label;

    [GtkChild]
    private Gtk.Label timer_name;

    [GtkChild]
    private Gtk.Stack name_stack;

    [GtkChild]
    private Gtk.Stack start_stack;
    [GtkChild]
    private Gtk.Stack reset_stack;
    [GtkChild]
    private Gtk.Stack delete_stack;

    [GtkChild]
    private Gtk.Button reset_button;
    [GtkChild]
    private Gtk.Button delete_button;
    [GtkChild]
    private Gtk.Button pause_button;
    [GtkChild]
    private Gtk.Button start_button;
    [GtkChild]
    private Gtk.Entry title;

    public signal void deleted ();
    public signal void edited ();
    public signal void ringing ();


    public Row (Item item) {
        Object (item: item);
        span = item.duration.get_total_seconds ();
        timer = new GLib.Timer ();

        timeout_id = 0;
        destroy.connect (() => {
            if (timeout_id != 0) {
                GLib.Source.remove (timeout_id);
                timeout_id = 0;
            }
        });
        delete_button.clicked.connect (() => deleted ());
        // Not sure why I keep getting the flat class locally.
        reset_button.get_style_context ().remove_class ("flat");
        delete_button.get_style_context ().remove_class ("flat");
        start_button.get_style_context ().remove_class ("flat");
        pause_button.get_style_context ().remove_class ("flat");

        reset ();
    }

    [GtkCallback]
    private void on_start_button_clicked () {
        switch (state) {
        case State.PAUSED:
        case State.STOPPED:
            start ();
            break;
        default:
            assert_not_reached ();
        }
    }

    [GtkCallback]
    private void on_pause_button_clicked () {
        switch (state) {
        case State.RUNNING:
            pause ();
            break;
        default:
            assert_not_reached ();
        }
    }

    [GtkCallback]
    private void on_reset_button_clicked () {
        reset ();
    }

    private void reset () {
        update_name_label ();
        state = State.STOPPED;
        span = item.duration.get_total_seconds ();

        update_countdown_label (item.duration.hours, item.duration.minutes, item.duration.seconds);

        reset_stack.visible_child_name = "empty";
        delete_stack.visible_child_name = "button";

        timer.reset ();
        countdown_label.get_style_context ().add_class ("timer-paused");
        countdown_label.get_style_context ().remove_class ("timer-ringing");
        countdown_label.get_style_context ().remove_class ("timer-running");
        start_stack.visible_child_name = "start";
        name_stack.visible_child_name = "edit";
    }

    private void start () {
        update_name_label ();
        countdown_label.get_style_context ().add_class ("timer-running");
        countdown_label.get_style_context ().remove_class ("timer-ringing");
        countdown_label.get_style_context ().remove_class ("timer-paused");

        reset_stack.visible_child_name = "empty";
        delete_stack.visible_child_name = "empty";

        start_stack.visible_child_name = "pause";
        name_stack.visible_child_name = "display";
        state = State.RUNNING;
        timer.start ();
        timeout_id = GLib.Timeout.add (40, () => {
            if (state != State.RUNNING) {
                timeout_id = 0;
                return false;
            }
            var e = timer.elapsed ();
            if (e >= span) {
                reset ();
                ring ();
                timeout_id = 0;
                return false;
            }
            update_countdown (e);
            return true;
        });
    }

    private void ring () {
        countdown_label.get_style_context ().add_class ("timer-ringing");
        countdown_label.get_style_context ().remove_class ("timer-paused");
        countdown_label.get_style_context ().remove_class ("timer-running");

        ringing ();
    }

    private void pause () {
        countdown_label.get_style_context ().add_class ("timer-paused");
        countdown_label.get_style_context ().remove_class ("timer-ringing");
        countdown_label.get_style_context ().remove_class ("timer-running");

        reset_stack.visible_child_name = "button";
        delete_stack.visible_child_name = "button";

        state = State.PAUSED;
        timer.stop ();
        span -= timer.elapsed ();
        start_stack.visible_child_name = "start";
        name_stack.visible_child_name = "display";
    }

    private void update_countdown (double elapsed) {
        if (countdown_label.get_mapped ()) {
            // Math.ceil() because we count backwards:
            // with 0.3 seconds we want to show 1 second remaining,
            // with 59.2 seconds we want to show 1 minute, etc
            double t = Math.ceil (span - elapsed);
            int h;
            int m;
            int s;
            double r;
            Utils.time_to_hms (t, out h, out m, out s, out r);
            update_countdown_label (h, m, s);
        }
    }

    private void update_countdown_label (int h, int m, int s) {
        countdown_label.set_text ("%02i:%02i:%02i".printf (h, m, s));
    }

    private void update_name_label () {
        if (item.name != null && item.name != "") {
            timer_name.label = item.name;
        } else {
            timer_name.label = _("%i minutes timer".printf(item.duration.minutes));
        }
    }
}


[GtkTemplate (ui = "/org/gnome/clocks/ui/timer.ui")]
public class Face : Gtk.Stack, Clocks.Clock {
    public enum State {
        EMPTY,
        RUNNING,
    }

    private Setup timer_setup;
    [GtkChild]
    private Gtk.ListBox timers_list;
    [GtkChild]
    private Gtk.Box no_timer_container;
    [GtkChild]
    private Gtk.Button start_button;

    public PanelId panel_id { get; construct set; }
    public ButtonMode button_mode { get; set; default = NONE; }
    public ViewMode view_mode { get; set; default = NORMAL; }
    public State state { get; set; default = State.EMPTY; }
    public bool can_select { get; set; default = false; }
    public bool n_selected { get; set; }
    public string title { get; set; default = _("Clocks"); }
    public string subtitle { get; set; }
    // Translators: Tooltip for the + button
    public string new_label { get; default = _("New Timer"); }

    private ContentStore timers;
    private GLib.Settings settings;
    private Utils.Bell bell;
    private GLib.Notification notification;

    construct {
        panel_id = TIMER;
        transition_type = CROSSFADE;
        timer_setup = new Setup ();

        settings = new GLib.Settings ("org.gnome.clocks");
        timers = new ContentStore ();

        timers_list.set_header_func ((Gtk.ListBoxUpdateHeaderFunc) Hdy.list_box_separator_header);
        timers_list.bind_model (timers, (timer) => {
            var row = new Row ((Item) timer);
            row.deleted.connect (() => remove_timer ((Item) timer));
            row.edited.connect (() => save ());
            row.ringing.connect (() => ring ());
            return row;
        });

        timers.items_changed.connect (() => {
            if (this.timers.get_n_items () > 0) {
                this.visible_child_name = "timers";
                this.button_mode = NEW;
            } else {
                this.visible_child_name = "empty";
                this.button_mode = NONE;
            }
            save ();
        });

        bell = new Utils.Bell ("complete");
        notification = new GLib.Notification (_("Time is up!"));
        notification.set_body (_("Timer countdown finished"));

        no_timer_container.add (timer_setup);
        no_timer_container.reorder_child (timer_setup, 0);
        set_visible_child_name ("empty");

        start_button.set_sensitive (false);
        timer_setup.duration_changed.connect ((duration) => {
            start_button.set_sensitive (duration.get_total_seconds () != 0);
        });
        start_button.clicked.connect (() => {
            var timer = this.timer_setup.get_timer ();
            this.add_timer (timer);
        });
        load ();
    }

    private void remove_timer (Item item) {
        timers.remove (item);
    }

    public void activate_new () {
        var dialog = new NewTimerDialog ((Gtk.Window) get_toplevel ());
        dialog.response.connect ((dialog, response) => {
            if (response == Gtk.ResponseType.ACCEPT) {
                var timer = ((NewTimerDialog) dialog).timer_setup.get_timer ();
                timers.add (timer);
            }
            dialog.destroy ();
        });
        dialog.show ();
    }


    private void add_timer (Item timer) {
        timers.add (timer);
    }

    private void load () {
        timers.deserialize (settings.get_value ("timers"), Item.deserialize);
    }

    private void save () {
        settings.set_value ("timers", timers.serialize ());
    }

    public virtual signal void ring () {
        var app = GLib.Application.get_default () as Clocks.Application;
        app.send_notification ("timer-is-up", notification);
        bell.ring_once ();
    }

    public override void grab_focus () {
        /*if (visible_child == setup_frame) {
            start_button.grab_focus ();
        }
        */
    }

    public bool escape_pressed () {
        /*if (state == State.STOPPED) {
            return false;
        }

        reset ();

        return true;
        */
       return false;
    }
}

} // namespace Timer
} // namespace Clocks
