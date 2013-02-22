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

public class MainPanel : Gtk.Box, Clocks.Clock {
    private enum State {
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
    public Toolbar toolbar { get; construct set; }

    private State state;
    private GLib.Timer timer;
    private uint timeout_id;
    private int current_lap;
    private double last_lap_time;
    private Gtk.Label time_label;
    private Gtk.Button left_button;
    private Gtk.Button right_button;
    private Gtk.ListStore laps_model;
    private Gtk.TreeView laps_view;

    public MainPanel (Toolbar toolbar) {
        Object (label: _("Stopwatch"), toolbar: toolbar);

        timer = new GLib.Timer ();
        timeout_id = 0;

        var builder = Utils.load_ui ("stopwatch.ui");

        var stopwatch_panel = builder.get_object ("stopwatch_panel") as Gtk.Widget;
        time_label = builder.get_object ("time_label") as Gtk.Label;
        left_button = builder.get_object ("left_button") as Gtk.Button;
        right_button = builder.get_object ("right_button") as Gtk.Button;
        laps_model = builder.get_object ("laps_model") as Gtk.ListStore;
        laps_view = builder.get_object ("laps_view") as Gtk.TreeView;

        left_button.clicked.connect (on_left_button_clicked);
        right_button.clicked.connect (on_right_button_clicked);

        map.connect ((w) => {
            if (state == State.RUNNING) {
                update_time_label ();
                add_timeout ();
            }
        });

        unmap.connect ((w) => {
            if (state == State.RUNNING) {
                remove_timeout ();
            }
        });

        reset ();

        add (stopwatch_panel);
        show_all ();
    }

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
        add_timeout ();
        left_button.set_label (_("Stop"));
        left_button.get_style_context ().add_class ("clocks-stop");
        right_button.set_sensitive (true);
        right_button.set_label (_("Lap"));
    }

    private void stop () {
        timer.stop ();
        state = State.STOPPED;
        remove_timeout ();
        left_button.set_label (_("Continue"));
        left_button.get_style_context ().remove_class ("clocks-stop");
        left_button.get_style_context ().add_class ("clocks-go");
        right_button.set_sensitive (true);
        right_button.set_label (_("Reset"));
    }

    private void reset () {
        timer.reset ();
        state = State.RESET;
        remove_timeout ();
        update_time_label ();
        left_button.set_label (_("Start"));
        left_button.get_style_context ().add_class ("clocks-go");
        right_button.set_sensitive (false);
        current_lap = 0;
        last_lap_time = 0;
        laps_model.clear ();
    }

    private void lap () {
        current_lap += 1;
        var e = timer.elapsed ();
        var split = e - last_lap_time;
        last_lap_time = e;

        int h;
        int m;
        double s;
        Utils.time_to_hms (e, out h, out m, out s);

        int split_h;
        int split_m;
        double split_s;
        Utils.time_to_hms (split, out split_h, out split_m, out split_s);

        var n_label = "<span color='dimgray'> %d </span>".printf (current_lap);

        string split_label;
        if (split_h > 0) {
            split_label = "%i:%02i:%05.2f".printf (split_h, split_m, split_s);
        } else {
            split_label = "%02i:%05.2f".printf (split_m, split_s);
        }

        string tot_label;
        if (h > 0) {
            tot_label = "%i:%02i:%05.2f".printf (h, m, s);
        } else {
            tot_label = "%02i:%05.2f".printf (m, s);
        }

        Gtk.TreeIter i;
        laps_model.append (out i);
        laps_model.set (i,
                        LapsColumn.LAP, n_label,
                        LapsColumn.SPLIT, split_label,
                        LapsColumn.TOTAL, tot_label);
        var p = laps_model.get_path (i);
        laps_view.scroll_to_cell (p, null, false, 0, 0);
    }

    private void add_timeout () {
        if (timeout_id == 0) {
            timeout_id = Timeout.add (100, update_time_label);
        }
    }

    private void remove_timeout () {
        if (timeout_id != 0) {
            Source.remove (timeout_id);
            timeout_id = 0;
        }
    }

    private bool update_time_label () {
        int h = 0;
        int m = 0;
        double s = 0;
        if (state != State.RESET) {
            Utils.time_to_hms (timer.elapsed (), out h, out m, out s);
        }

        if (h > 0) {
            time_label.set_text ("%i:%02i:%04.1f".printf (h, m, s));
        } else {
            time_label.set_text ("%02i:%04.1f".printf (m, s));
        }

        return true;
    }
}

} // namespace Stopwatch
} // namespace Clocks
