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


public class Item : Object, ContentItem {
    public bool selectable { get; set; default = false; }
    public bool selected { get; set; default = false; }

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



[GtkTemplate (ui = "/org/gnome/clocks/ui/timerrow.ui")]
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
    private Gtk.Box setup_frame;
    [GtkChild]
    private Gtk.Grid grid_spinbuttons;
    [GtkChild]
    private Gtk.Grid grid_labels;
    [GtkChild]
    private Gtk.SpinButton h_spinbutton;
    [GtkChild]
    private Gtk.SpinButton m_spinbutton;
    [GtkChild]
    private Gtk.SpinButton s_spinbutton;
    [GtkChild]
    private Gtk.Button start_button;
    [GtkChild]
    private Gtk.Button pause_button;
    [GtkChild]
    private Gtk.Box countdown_frame;
    [GtkChild]
    private Gtk.Stack timer_stack;
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

        // Force LTR since we do not want to reverse [hh] : [mm] : [ss]
        grid_spinbuttons.set_direction (Gtk.TextDirection.LTR);
        grid_labels.set_direction (Gtk.TextDirection.LTR);

        reset ();
    }


    [GtkCallback]
    private bool show_leading_zeros (Gtk.SpinButton spin_button) {
        spin_button.set_text ("%02i".printf(spin_button.get_value_as_int ()));
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

    [GtkCallback]
    private void update_start_button () {
        var h = h_spinbutton.get_value_as_int ();
        var m = m_spinbutton.get_value_as_int ();
        var s = s_spinbutton.get_value_as_int ();

        if (h != 0 || m != 0 || s != 0) {
            start_button.set_sensitive (true);
        } else {
            start_button.set_sensitive (false);
        }
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
        h_spinbutton.value = item.hours;
        m_spinbutton.value = item.minutes;
        s_spinbutton.value = item.seconds;
        countdown_frame.get_style_context ().remove_class ("clocks-paused");
        start_button.set_sensitive (item.in_seconds() > 0);
        timer_stack.visible_child = setup_frame;
        start_stack.visible_child_name = "start";
    }

    private void start () {
        countdown_frame.get_style_context ().remove_class ("clocks-paused");

        if (state == State.STOPPED) {
            var h = h_spinbutton.get_value_as_int ();
            var m = m_spinbutton.get_value_as_int ();
            var s = s_spinbutton.get_value_as_int ();

            span = h * 3600 + m * 60 + s;
            // settings.set_uint ("timer", (uint) span);
            // countdown_frame.span = span;
            timer_stack.visible_child = countdown_frame;

            update_countdown_label (h, m, s);
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
        if (timer_stack.visible_child == setup_frame) {
            start_button.grab_focus ();
        }
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
    public string label { get; construct set; }
    public string icon_name { get; construct set; }

    public PanelId panel_id { get; construct set; }

    [GtkChild]
    private ContentView content_view;
    public Gtk.Widget? header_actions_widget{ get; set; }

    private Utils.Bell bell;
    private GLib.Notification notification;
    private ContentStore timers;
    private GLib.Settings settings;

    public Face() {
        Object (label: _("Timer"),
                icon_name: "timer-symbolic",
                panel_id: PanelId.TIMER);

        bell = new Utils.Bell ("complete");
        notification = new GLib.Notification (_("Time is up!"));
        notification.set_body (_("Timer countdown finished"));

        timers = new ContentStore ();
        settings = new GLib.Settings ("org.gnome.clocks");

        timers.set_sorting ((item1, item2) => {
            /*var offset1 = ((Item) item1).location.get_timezone ().get_offset ();
            var offset2 = ((Item) item2).location.get_timezone ().get_offset ();
            if (offset1 < offset2)
                return -1;
            if (offset1 > offset2)
                return 1;
            return 0;
            */
           return 1;
        });

        content_view.bind_model (timers, (item) => {
            return new Row((Item)item);
        });

        var new_button = new Gtk.Button.from_icon_name ("list-add-symbolic", Gtk.IconSize.BUTTON);
        new_button.valign = Gtk.Align.CENTER;
        new_button.clicked.connect(on_add_clicked);
        header_actions_widget = new_button;
    }

    private void add_timer_item (Item item) {
        timers.add (item);
        visible_child_name = "timers";
        save ();
    }

    private void on_add_clicked (Gtk.Button widget) {
        var item = new Item (GLib.Time.gm(0), "");
        add_timer_item (item);

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
}

} // namespace Timer
} // namespace Clocks
