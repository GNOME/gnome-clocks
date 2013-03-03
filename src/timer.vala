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

public class MainPanel : Gd.Stack, Clocks.Clock {
    enum State {
        STOPPED,
        RUNNING,
        PAUSED
    }

    public string label { get; construct set; }
    public Toolbar toolbar { get; construct set; }

    private State state;
    private uint timeout_id;
    private Utils.Bell bell;
    private Gtk.Widget setup_panel;
    private Gtk.SpinButton h_spinbutton;
    private Gtk.SpinButton m_spinbutton;
    private Gtk.SpinButton s_spinbutton;
    private Gtk.Button start_button;
    private Gtk.Widget countdown_panel;
    private Gtk.Label time_label;
    private Gtk.Button left_button;
    private Gtk.Button right_button;
    private double span;
    private GLib.Timer timer;

    public MainPanel (Toolbar toolbar) {
        Object (label: _("Timer"), toolbar: toolbar, transition_type: Gd.StackTransitionType.CROSSFADE);

        bell = new Utils.Bell ("complete", _("Time is up!"), _("Timer countdown finished"));

        timeout_id = 0;
        span = 0;
        timer = new GLib.Timer ();

        var builder = Utils.load_ui ("timer.ui");

        setup_panel = builder.get_object ("setup_panel") as Gtk.Widget;
        h_spinbutton = builder.get_object ("spinbutton_hours") as Gtk.SpinButton;
        m_spinbutton = builder.get_object ("spinbutton_minutes") as Gtk.SpinButton;
        s_spinbutton = builder.get_object ("spinbutton_seconds") as Gtk.SpinButton;
        start_button = builder.get_object ("start_button") as Gtk.Button;

        h_spinbutton.output.connect (show_leading_zeros);
        m_spinbutton.output.connect (show_leading_zeros);
        s_spinbutton.output.connect (show_leading_zeros);

        h_spinbutton.value_changed.connect (update_start_button);
        m_spinbutton.value_changed.connect (update_start_button);
        s_spinbutton.value_changed.connect (update_start_button);

        start_button.clicked.connect (() => {
            start ();
        });

        countdown_panel = builder.get_object ("countdown_panel") as Gtk.Widget;
        time_label = builder.get_object ("time_label") as Gtk.Label;
        left_button = builder.get_object ("left_button") as Gtk.Button;
        right_button = builder.get_object ("right_button") as Gtk.Button;

        left_button.clicked.connect (() => {
            switch (state) {
            case State.RUNNING:
                pause ();
                left_button.set_label (_("Continue"));
                left_button.get_style_context ().add_class ("clocks-go");
                break;
            case State.PAUSED:
                restart ();
                left_button.set_label (_("Pause"));
                left_button.get_style_context ().remove_class("clocks-go");
                break;
            default:
                assert_not_reached ();
            }
        });

        right_button.clicked.connect (() => {
            reset ();
            left_button.set_label (_("Pause"));
        });

        add (setup_panel);
        add (countdown_panel);

        reset ();

        visible_child = setup_panel;
        show_all ();
    }

    public virtual signal void ring () {
        bell.ring_once ();
    }

    private bool show_leading_zeros (Gtk.SpinButton spin_button) {
        spin_button.set_text ("%02i".printf(spin_button.get_value_as_int ()));
        return true;
    }

    private void update_start_button () {
        var h = h_spinbutton.get_value_as_int ();
        var m = m_spinbutton.get_value_as_int ();
        var s = s_spinbutton.get_value_as_int ();

        if (h != 0 || m != 0 || s != 0) {
            start_button.set_sensitive (true);
            start_button.get_style_context ().add_class ("clocks-go");
        } else {
            start_button.set_sensitive (false);
            start_button.get_style_context ().remove_class ("clocks-go");
        }
    }

    private void reset () {
        state = State.STOPPED;
        timer.reset ();
        remove_timeout ();
        span = 0;
        h_spinbutton.value = 0;
        m_spinbutton.value = 0;
        s_spinbutton.value = 0;
        start_button.set_sensitive (false);
        visible_child = setup_panel;
    }

    private void start () {
        if (state == State.STOPPED && timeout_id == 0) {
            var h = h_spinbutton.get_value_as_int ();
            var m = m_spinbutton.get_value_as_int ();
            var s = s_spinbutton.get_value_as_int ();

            state = State.RUNNING;
            span = h * 3600 + m * 60 + s;
            timer.start ();

            visible_child = countdown_panel;

            update_countdown_label (h, m, s);
            add_timeout ();
        }
    }

    private void restart () {
        state = State.RUNNING;
        timer.start ();
        add_timeout ();
    }

    private void pause () {
        state = State.PAUSED;
        timer.stop ();
        span -= timer.elapsed ();
        remove_timeout ();
    }

    private void add_timeout () {
        if (timeout_id == 0) {
            timeout_id = Timeout.add (100, count);
        }
    }

    private void remove_timeout () {
        if (timeout_id != 0) {
            Source.remove (timeout_id);
            timeout_id = 0;
        }
    }

    private bool count () {
        var e = timer.elapsed ();
        if (e >= span) {
            ring ();
            state = State.STOPPED;
            remove_timeout ();
            update_countdown_label (0, 0, 0);
            visible_child = setup_panel;
            return false;
        }

        update_countdown (span - e);
        return true;
    }

    private void update_countdown (double t) {
        if (time_label.get_mapped ()) {
            int h;
            int m;
            double s;
            Utils.time_to_hms (t, out h, out m, out s);

            // Math.ceil() because we count backwards: with 0.3 seconds
            // we want to show 1 second remaining
            update_countdown_label (h, m, (int)Math.ceil(s));
        }
    }

    private void update_countdown_label (int h, int m, int s) {
        // Note that the format uses unicode RATIO character
        time_label.set_text ("%02i∶%02i∶%02i".printf (h, m, s));
    }
}

} // namespace Timer
} // namespace Clocks
