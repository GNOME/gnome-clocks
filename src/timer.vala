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

public class CountdownFrame : AnalogFrame {
    public double span { get; set; default = 0; }

    private double elapsed;
    private double elapsed_before_pause;

    private double get_progress () {
        return span != 0 ? (elapsed_before_pause + elapsed) / span : 0;
    }

    public void update (double e) {
        elapsed = e;
        queue_draw ();
    }

    public void pause () {
        elapsed_before_pause += elapsed;
        elapsed = 0;
    }

    public void reset () {
        elapsed_before_pause = 0;
        elapsed = 0;
    }

    public override void draw_progress (Cairo.Context cr, int center_x, int center_y, int radius) {
        var context = get_style_context ();

        context.save ();
        context.add_class ("progress");

        cr.set_line_width (LINE_WIDTH);
        cr.set_line_cap  (Cairo.LineCap.ROUND);

        var color = context.get_color (Gtk.StateFlags.NORMAL);

        var progress = get_progress ();
        cr.arc (center_x, center_y, radius - LINE_WIDTH / 2, 1.5  * Math.PI, (1.5 + (1 - progress) * 2 ) * Math.PI);
        Gdk.cairo_set_source_rgba (cr, color);
        cr.stroke ();

        context.restore ();
    }
}

[GtkTemplate (ui = "/org/gnome/clocks/ui/timer.ui")]
public class MainPanel : Gtk.Stack, Clocks.Clock {
    public enum State {
        STOPPED,
        RUNNING,
        PAUSED
    }

    public string label { get; construct set; }
    public HeaderBar header_bar { get; construct set; }
    public PanelId panel_id { get; construct set; }

    public State state { get; private set; default = State.STOPPED; }

    private GLib.Settings settings;
    private uint tick_id;
    private double span;
    private GLib.Timer timer;
    private Utils.Bell bell;
    private GLib.Notification notification;
    [GtkChild]
    private AnalogFrame setup_frame;
    [GtkChild]
    private Gtk.Grid grid_spinbuttons;
    [GtkChild]
    private Gtk.SpinButton h_spinbutton;
    [GtkChild]
    private Gtk.SpinButton m_spinbutton;
    [GtkChild]
    private Gtk.SpinButton s_spinbutton;
    [GtkChild]
    private Gtk.Button start_button;
    [GtkChild]
    private CountdownFrame countdown_frame;
    [GtkChild]
    private Gtk.Label countdown_label;
    [GtkChild]
    private Gtk.Button left_button;

    public MainPanel (HeaderBar header_bar) {
        Object (label: _("Timer"), header_bar: header_bar, transition_type: Gtk.StackTransitionType.CROSSFADE, panel_id: PanelId.TIMER);

        settings = new GLib.Settings ("org.gnome.clocks");

        tick_id = 0;
        span = 0;
        timer = new GLib.Timer ();

        bell = new Utils.Bell ("complete");
        notification = new GLib.Notification (_("Time is up!"));
        notification.set_body (_("Timer countdown finished"));

        // Force LTR since we do not want to reverse [hh] : [mm] : [ss]
        grid_spinbuttons.set_direction (Gtk.TextDirection.LTR);

        reset ();
    }

    public virtual signal void ring () {
        var app = GLib.Application.get_default ();
        app.send_notification (null, notification);
        bell.ring_once ();
    }

    [GtkCallback]
    private bool show_leading_zeros (Gtk.SpinButton spin_button) {
        spin_button.set_text ("%02i".printf(spin_button.get_value_as_int ()));
        return true;
    }

    [GtkCallback]
    private void update_start_button () {
        var h = h_spinbutton.get_value_as_int ();
        var m = m_spinbutton.get_value_as_int ();
        var s = s_spinbutton.get_value_as_int ();

        if (h != 0 || m != 0 || s != 0) {
            start_button.set_sensitive (true);
            start_button.get_style_context ().add_class ("suggested-action");
        } else {
            start_button.set_sensitive (false);
            start_button.get_style_context ().remove_class ("suggested-action");
        }
    }

    [GtkCallback]
    private void on_start_button_clicked () {
        start ();
    }

    [GtkCallback]
    private void on_left_button_clicked () {
        switch (state) {
        case State.RUNNING:
            pause ();
            left_button.set_label (_("Continue"));
            left_button.get_style_context ().add_class ("suggested-action");
            break;
        case State.PAUSED:
            restart ();
            left_button.set_label (_("Pause"));
            left_button.get_style_context ().remove_class("suggested-action");
            break;
        default:
            assert_not_reached ();
        }
    }

    [GtkCallback]
    private void on_right_button_clicked () {
        reset ();
        left_button.set_label (_("Pause"));
    }

    private void reset () {
        state = State.STOPPED;
        timer.reset ();
        remove_tick ();
        span = settings.get_uint ("timer");
        h_spinbutton.value = (int) span / 3600;
        m_spinbutton.value = (int) span / 60;
        s_spinbutton.value = span % 60;
        left_button.get_style_context ().remove_class("clocks-go");
        countdown_label.get_style_context ().remove_class ("clocks-blink");
        start_button.set_sensitive (span > 0);
        countdown_frame.reset ();
        visible_child = setup_frame;
    }

    private void start () {
        if (state == State.STOPPED && tick_id == 0) {
            var h = h_spinbutton.get_value_as_int ();
            var m = m_spinbutton.get_value_as_int ();
            var s = s_spinbutton.get_value_as_int ();

            state = State.RUNNING;
            span = h * 3600 + m * 60 + s;

            settings.set_uint ("timer", (uint) span);

            timer.start ();

            countdown_frame.span = span;
            visible_child = countdown_frame;

            update_countdown_label (h, m, s);
            add_tick ();
        }
    }

    private void restart () {
        state = State.RUNNING;
        timer.start ();
        add_tick ();
        countdown_label.get_style_context ().remove_class ("clocks-blink");
    }

    private void pause () {
        state = State.PAUSED;
        timer.stop ();
        span -= timer.elapsed ();
        countdown_frame.pause ();
        remove_tick ();
        countdown_label.get_style_context ().add_class ("clocks-blink");
    }

    private void add_tick () {
        if (tick_id == 0) {
            tick_id = add_tick_callback ((c) => {
                return count ();
            });
        }
    }

    private void remove_tick () {
        if (tick_id != 0) {
            remove_tick_callback (tick_id);
            tick_id = 0;
        }
    }

    private bool count () {
        var e = timer.elapsed ();
        if (e >= span) {
            ring ();
            state = State.STOPPED;
            remove_tick ();
            update_countdown_label (0, 0, 0);
            visible_child = setup_frame;
            return false;
        }

        update_countdown (e);
        return true;
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
            countdown_frame.update (elapsed);
        }
    }

    private void update_countdown_label (int h, int m, int s) {
        // Note that the format uses unicode RATIO character
        // We also prepend the LTR mark to make sure text is always in this direction
        countdown_label.set_text ("%02i\xE2\x80\x8E∶%02i\xE2\x80\x8E∶%02i".printf (h, m, s));
    }

    public override void grab_focus () {
        if (visible_child == setup_frame) {
            start_button.grab_focus ();
        }
    }
}

} // namespace Timer
} // namespace Clocks
