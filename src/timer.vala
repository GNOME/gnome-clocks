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
namespace Timer {

public class Item : Object {


    public string name {
        get {
            return _name;
        }
        set {
            // ignored
        }
    }

    public int hours {
        get {
            return timer.hour;
        }
    }
    public int minutes {
        get {
            return timer.minute;
        }
    }

    public int seconds {
        get {
            return timer.second;
        }
    }

    public int in_seconds() {
        return timer.second + timer.minute * 60 + timer.hour * 3600;
    }

    private string _name;
    public GLib.Time timer { get; set; }

    public void serialize (GLib.VariantBuilder builder) {
        builder.open (new GLib.VariantType ("a{sv}"));
        builder.add ("{sv}", "time", new GLib.Variant.int32(in_seconds()));
        if (name != null) {
            builder.add ("{sv}", "name", new GLib.Variant.string(name));
        }
        builder.close ();
    }

    public static Item? deserialize (GLib.Variant time_variant) {
        GLib.Time? time = null;
        string? name = null;

        foreach (var v in time_variant) {
            var key = v.get_child_value (0).get_string ();
            switch (key) {
                case "time":
                    time = GLib.Time.gm(v.get_child_value (1).get_child_value (0).get_int32());
                    break;
                case "name":
                    name = v.get_child_value (1).get_child_value (0).get_string();
                    break;
            }
        }
        return time != null ? new Item (time, name) : null;
    }

    public Item (GLib.Time timer, string name) {
        Object (name: name);
        this.timer = timer;
    }
}


public class TimersStore: Object, GLib.ListModel {
    private ListStore store;

    public TimersStore () {
        store = new ListStore (typeof (Item));
    }

    public void add(Item timer) {
       store.append (timer);
    }

    public Type get_item_type () {
        return store.get_item_type ();
    }

    public uint get_n_items () {
        return store.get_n_items ();
    }

    public Object? get_item (uint position) {
        return store.get_item (position);
    }


    public Variant serialize () {
        var builder = new GLib.VariantBuilder (new VariantType ("aa{sv}"));
        var n = store.get_n_items ();
        for (int i = 0; i < n; i++) {
            var item = store.get_object (i) as Item;
            item.serialize (builder);
        }
        return builder.end ();
    }

    public delegate Item? DeserializeItemFunc (Variant v);

    public void deserialize (Variant variant, DeserializeItemFunc deserialize_item) {
        foreach (var v in variant) {
            Item? i = deserialize_item (v);
            if (i != null) {
                store.append (i);
            }
        }
    }
}

public class NewTimerDialog: Hdy.Dialog {

    private new Gtk.Button add_button;
    private Gtk.Button cancel_button;
    private Setup timer_setup;

    public NewTimerDialog (Gtk.Window parent, Item? timer) {
        Object (transient_for: parent, title: timer != null ? _("Edit Timer") : _("New Timer"), use_header_bar: 1);
        this.set_default_size (640, 360);

        var headerbar = (Gtk.HeaderBar)this.get_header_bar ();
        headerbar.set_show_close_button (false);

        add_button = new Gtk.Button.with_label (_("Add"));
        add_button.get_style_context ().add_class ("suggested-action");
        add_button.set_sensitive (false);
        add_button.show ();
        headerbar.pack_end (add_button);

        cancel_button = new Gtk.Button.with_label (_("Cancel"));
        cancel_button.clicked.connect ( () => this.destroy ());
        cancel_button.show ();
        headerbar.pack_start (cancel_button);

        timer_setup = new Setup ();
        this.get_content_area ().add (timer_setup);


    }
}


[GtkTemplate (ui = "/org/gnome/clocks/ui/timer_setup.ui")]
public class Setup : Gtk.Box {

    [GtkChild]
    private Gtk.Button predefined_1m;
    [GtkChild]
    private Gtk.Button predefined_2m;
    [GtkChild]
    private Gtk.Button predefined_3m;
    [GtkChild]
    private Gtk.Button predefined_5m;
    [GtkChild]
    private Gtk.Button predefined_15m;
    [GtkChild]
    private Gtk.Button predefined_30m;
    [GtkChild]
    private Gtk.Button predefined_45m;
    [GtkChild]
    private Gtk.Button predefined_1h;
    [GtkChild]
    private Gtk.SpinButton h_spinbutton;
    [GtkChild]
    private Gtk.SpinButton m_spinbutton;
    [GtkChild]
    private Gtk.SpinButton s_spinbutton;

    public Setup() {
        predefined_1m.clicked.connect(() => this.update_timer(0, 1, 0));
        predefined_2m.clicked.connect(() => this.update_timer(0, 2, 0));
        predefined_3m.clicked.connect(() => this.update_timer(0, 3, 0));
        predefined_5m.clicked.connect(() => this.update_timer(0, 5, 0));
        predefined_15m.clicked.connect(() => this.update_timer(0, 15, 0));
        predefined_30m.clicked.connect(() => this.update_timer(0, 30, 0));
        predefined_45m.clicked.connect(() => this.update_timer(0, 45, 0));
        predefined_1h.clicked.connect(() => this.update_timer(1, 0, 0));

    }

    public Item get_timer() {
        var h = this.h_spinbutton.get_value();
        var m = this.m_spinbutton.get_value();
        var s = this.s_spinbutton.get_value();
        time_t total_seconds = (time_t)(h * 3600 + m * 60 + s);

        var time = GLib.Time.gm(total_seconds);
        return (new Item (time, ""));
    }


    private void update_timer(int h, int m, int s) {
        this.h_spinbutton.set_value(h);
        this.m_spinbutton.set_value(m);
        this.s_spinbutton.set_value(s);
    }

    [GtkCallback]
    private bool show_leading_zeros (Gtk.SpinButton spin_button) {
        spin_button.set_text ("%02i".printf(spin_button.get_value_as_int ()));
        return true;
    }
    [GtkCallback]
    private void update_start_button () {
       /* var h = h_spinbutton.get_value_as_int ();
        var m = m_spinbutton.get_value_as_int ();
        var s = s_spinbutton.get_value_as_int ();

        if (h != 0 || m != 0 || s != 0) {
            start_button.set_sensitive (true);
        } else {
            start_button.set_sensitive (false);
        }*/
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
public class Row : Gtk.Box {
    public enum State {
        STOPPED,
        RUNNING,
        PAUSED
    }

    public State state { get; private set; default = State.STOPPED; }
    public Item item { get; construct set; }

    private double span;
    private GLib.Timer timer;
    private uint timeout_id;
    [GtkChild]
    private Gtk.Button start_button;
    [GtkChild]
    private Gtk.Box countdown_frame;
    [GtkChild]
    private Gtk.Stack start_stack;
    [GtkChild]
    // We cheat and use spibuttons also when displaying the time
    // making them insensitive and hiding the +/- via css
    // this is needed to ensure the text does not move in the transition
    private Gtk.SpinButton h_label;
    [GtkChild]
    private Gtk.SpinButton m_label;
    [GtkChild]
    private Gtk.SpinButton s_label;

    public Row (Item item) {
        Object(item: item);
        span = 0;
        timer = new GLib.Timer ();

        timeout_id = 0;
        destroy.connect(() => {
            if (timeout_id != 0) {
                GLib.Source.remove(timeout_id);
                timeout_id = 0;
            }
        });
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
        state = State.STOPPED;
        timer.reset ();
        /*h_spinbutton.value = item.hours;
        m_spinbutton.value = item.minutes;
        s_spinbutton.value = item.seconds;
        */
        countdown_frame.get_style_context ().remove_class ("clocks-paused");
        start_button.set_sensitive (item.in_seconds() > 0);
        // timer_stack.visible_child = setup_frame;
        start_stack.visible_child_name = "start";
    }

    private void start () {
        countdown_frame.get_style_context ().remove_class ("clocks-paused");

        if (state == State.STOPPED) {
           /* var h = h_spinbutton.get_value_as_int ();
            var m = m_spinbutton.get_value_as_int ();
            var s = s_spinbutton.get_value_as_int ();

            span = h * 3600 + m * 60 + s;
            // settings.set_uint ("timer", (uint) span);
            // countdown_frame.span = span;
            timer_stack.visible_child = countdown_frame;

            update_countdown_label (h, m, s);
            */
        }
        start_stack.visible_child_name = "pause";

        state = State.RUNNING;
        timer.start ();
        timeout_id = GLib.Timeout.add(40, () => {
	    if (state != State.RUNNING) {
                timeout_id = 0;
                return false;
            }
            var e = timer.elapsed ();
            if (e >= span) {
                reset ();
                // ring ();
                timeout_id = 0;
                return false;
            }
            update_countdown (e);
            return true;
        });
    }

    private void pause () {
        state = State.PAUSED;
        timer.stop ();
        span -= timer.elapsed ();
        start_stack.visible_child_name = "start";
    }

    private void update_countdown (double elapsed) {
        if (h_label.get_mapped ()) {
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
        h_label.set_value (h);
        m_label.set_value (m);
        s_label.set_value (s);
    }

    public override void grab_focus () {
        /*if (timer_stack.visible_child == setup_frame) {
            start_button.grab_focus ();
        }*/
    }

    public bool escape_pressed () {
        if (state == State.STOPPED) {
            return false;
        }

        reset ();

        return true;
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

    private TimersStore timers;
    private GLib.Settings settings;
    private Utils.Bell bell;
    private GLib.Notification notification;

    construct {
        panel_id = TIMER;
        transition_type = CROSSFADE;
        timer_setup = new Setup ();

        settings = new GLib.Settings ("org.gnome.clocks");
        timers = new TimersStore();


        timers_list.set_header_func ((Gtk.ListBoxUpdateHeaderFunc) Hdy.list_box_separator_header);
        timers_list.bind_model (timers, (timer) => {
            var timer_row = new Row ((Item)timer);
            return timer_row;
        });

        timers.items_changed.connect(() => {
            if (this.timers.get_n_items () > 0) {
                this.set_visible_child_name ("timers");
                this.button_mode = NEW;
            } else {
                this.set_visible_child_name ("empty");
                this.button_mode = NONE;
            }
        });

        bell = new Utils.Bell ("complete");
        notification = new GLib.Notification (_("Time is up!"));
        notification.set_body (_("Timer countdown finished"));

        no_timer_container.add(timer_setup);
        no_timer_container.reorder_child(timer_setup, 0);
        set_visible_child_name ("empty");

        // start_button.set_sensitive(false);
        start_button.clicked.connect(() => {
            var timer = this.timer_setup.get_timer();
            this.add_timer(timer);
        });
        load ();
    }


    public void activate_new () {
        var dialog = new NewTimerDialog ((Gtk.Window) get_toplevel (), null);
        dialog.response.connect ((dialog, response) => {
            if (response == 1) {
                /* var alarm = new Item ();
                ((SetupDialog) dialog).apply_to_alarm (alarm);
                alarms.add (alarm);
                save ();*/
            }
            dialog.destroy ();
        });
        dialog.show ();
    }


    private void add_timer (Item timer) {
        timers.add (timer);
        visible_child_name = "timers";
        save ();
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
