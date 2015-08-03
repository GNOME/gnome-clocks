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
namespace Stopwatch {

public class Frame : AnalogFrame {
    private int seconds;
    private double millisecs;

    public void update (int s, double ms) {
        seconds = s;
        millisecs = ms;
        queue_draw ();
    }

    public void reset () {
        update (0, 0);
    }

    public override void draw_progress (Cairo.Context cr, int center_x, int center_y, int radius) {
        var context = get_style_context ();

        context.save ();
        context.add_class ("progress");

        cr.set_line_width (LINE_WIDTH);
        cr.set_line_cap  (Cairo.LineCap.ROUND);

        var color = context.get_color (Gtk.StateFlags.NORMAL);
        var progress = ((double) seconds + millisecs) / 60;
        if (progress > 0) {
            cr.arc (center_x,
                    center_y,
                    radius - LINE_WIDTH / 2,
                    1.5  * Math.PI,
                    (1.5 + progress * 2 ) * Math.PI);
            Gdk.cairo_set_source_rgba (cr, color);
            cr.stroke ();
        }

        context.restore ();

        context.save ();
        context.add_class ("progress-fast");

        cr.set_line_width (LINE_WIDTH - 2);
        color = context.get_color (Gtk.StateFlags.NORMAL);
        progress = millisecs;
        if (progress > 0) {
            cr.arc (center_x,
                    center_y,
                    radius - LINE_WIDTH / 2,
                    (1.5 + progress * 2 ) * Math.PI - 0.1,
                    (1.5 + progress * 2 ) * Math.PI + 0.1);
            Gdk.cairo_set_source_rgba (cr, color);
            cr.stroke ();
        }

        context.restore ();
    }
}

[GtkTemplate (ui = "/org/gnome/clocks/ui/stopwatchlapsrow.ui")]
private class LapsRow : Gtk.ListBoxRow {
    [GtkChild]
    private Gtk.Revealer slider;
    [GtkChild]
    private Gtk.Label num_label;
    [GtkChild]
    private Gtk.Label split_label;
    [GtkChild]
    private Gtk.Label tot_label;

    public LapsRow (string n, string split, string tot) {
        num_label.label = n;
        split_label.label = split;
        tot_label.label = tot;
    }

    public void slide_in () {
        slider.reveal_child = true;
    }
}

[GtkTemplate (ui = "/org/gnome/clocks/ui/stopwatch.ui")]
public class Face : Gtk.Box, Clocks.Clock {
    public enum State {
        RESET,
        RUNNING,
        STOPPED
    }

    private enum LapsColumn {
        LAP,
        SPLIT,
        TOTAL
    }

    public string label { get; construct set; }
    public HeaderBar header_bar { get; construct set; }
    public PanelId panel_id { get; construct set; }

    public State state { get; private set; default = State.RESET; }

    private GLib.Timer timer;
    private uint tick_id;
    private int current_lap;
    private double last_lap_time;
    [GtkChild]
    private Frame analog_frame;
    [GtkChild]
    private Gtk.Label time_label;
    [GtkChild]
    private Gtk.Button left_button;
    [GtkChild]
    private Gtk.Button right_button;
    [GtkChild]
    private Gtk.ScrolledWindow laps_scrollwin;
    [GtkChild]
    private Gtk.ListBox laps_list;

    public Face (HeaderBar header_bar) {
        Object (label: _("Stopwatch"),
                header_bar: header_bar,
                panel_id: PanelId.STOPWATCH);

        timer = new GLib.Timer ();
        tick_id = 0;

        map.connect ((w) => {
            if (state == State.RUNNING) {
                update_time_label ();
                add_tick ();
            }
        });

        unmap.connect ((w) => {
            if (state == State.RUNNING) {
                remove_tick ();
            }
        });

        reset ();
    }

    [GtkCallback]
    private void on_left_button_clicked (Gtk.Button button) {
        switch (state) {
        case State.RESET:
        case State.STOPPED:
            start ();
            break;
        case State.RUNNING:
            stop ();
            break;
        default:
            assert_not_reached ();
        }
    }

    [GtkCallback]
    private void on_right_button_clicked (Gtk.Button button) {
        switch (state) {
        case State.STOPPED:
            reset ();
            break;
        case State.RUNNING:
            lap ();
            break;
        default:
            assert_not_reached ();
        }
    }

    private void start () {
        if (state == State.RESET) {
            timer.start ();
        } else {
            timer.continue ();
        }
        state = State.RUNNING;
        add_tick ();
        left_button.set_label (_("Stop"));
        left_button.get_style_context ().add_class ("destructive-action");
        right_button.set_sensitive (true);
        right_button.set_label (_("Lap"));
    }

    private void stop () {
        timer.stop ();
        state = State.STOPPED;
        remove_tick ();
        left_button.set_label (_("Continue"));
        left_button.get_style_context ().remove_class ("destructive-action");
        left_button.get_style_context ().add_class ("suggested-action");
        right_button.set_sensitive (true);
        right_button.set_label (_("Reset"));
    }

    private void reset () {
        timer.reset ();
        state = State.RESET;
        remove_tick ();
        update_time_label ();
        left_button.set_label (_("Start"));
        left_button.get_style_context ().add_class ("suggested-action");
        right_button.set_sensitive (false);
        current_lap = 0;
        last_lap_time = 0;
        foreach (var l in laps_list.get_children ()) {
            laps_list.remove (l);
        }
    }

    private void lap () {
        current_lap += 1;
        var e = timer.elapsed ();
        var split = e - last_lap_time;

        // Discard milliseconds in the saved lap time to ensure
        // total and split times are consistent: for instance if we saved
        // 0.108000 and the next lap is 1.202000, we would see on screen 0.10
        // and 1.20, so we would expect a split time of 1.10, but we would
        // instead get 1.094000 and thus display 1.09
        last_lap_time = Math.floor(e * 100) / 100;

        int h;
        int m;
        int s;
        double r;
        Utils.time_to_hms (e, out h, out m, out s, out r);
        int cs = (int) (r * 100);

        int split_h;
        int split_m;
        int split_s;
        Utils.time_to_hms (split, out split_h, out split_m, out split_s, out r);
        int split_cs = (int) (r * 100);

        var n_label = "#%d".printf (current_lap);

        // Note that the format uses unicode RATIO character
        // We also prepend the LTR mark to make sure text is always in this direction

        string split_label;
        if (split_h > 0) {
            split_label = "%i\u200E∶%02i\u200E∶%02i.%02i".printf (split_h, split_m, split_s, split_cs);
        } else {
            split_label = "%02i\u200E∶%02i.%02i".printf (split_m, split_s, split_cs);
        }

        string tot_label;
        if (h > 0) {
            tot_label = "%i\u200E∶%02i\u200E∶%02i.%02i".printf (h, m, s, cs);
        } else {
            tot_label = "%02i\u200E∶%02i.%02i".printf (m, s, cs);
        }

        var row = new LapsRow (n_label, split_label, tot_label);

        // FIXME: we can remove this if ListBox gains support for :first-child
        if (current_lap == 1) {
            row.get_style_context ().add_class ("first-lap-row");
        }

        laps_list.prepend (row);
        row.slide_in ();
        laps_scrollwin.vadjustment.value = laps_scrollwin.vadjustment.lower;
    }

    private void add_tick () {
        if (tick_id == 0) {
            tick_id = add_tick_callback ((c) => {
                return update_time_label ();
            });
        }
    }

    private void remove_tick () {
        if (tick_id != 0) {
            remove_tick_callback (tick_id);
            tick_id = 0;
        }
    }

    private bool update_time_label () {
        int h = 0;
        int m = 0;
        int s = 0;
        double r = 0;
        if (state != State.RESET) {
            Utils.time_to_hms (timer.elapsed (), out h, out m, out s, out r);
        }

        int ds = (int) (r * 10);

        // Note that the format uses unicode RATIO character
        // We also prepend the LTR mark to make sure text is always in this direction
        if (h > 0) {
            time_label.set_text ("%i\u200E∶%02i\u200E∶%02i.%i".printf (h, m, s, ds));
        } else {
            time_label.set_text ("%02i\u200E∶%02i.%i".printf (m, s, ds));
        }

        analog_frame.update (s, r);

        return true;
    }

    public override void grab_focus () {
        left_button.grab_focus ();
    }
}

} // namespace Stopwatch
} // namespace Clocks
