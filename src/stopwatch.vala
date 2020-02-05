/*
 * Copyright (C) 2013  Paolo Borelli <pborelli@gnome.org>
 * Copyright (C) 2020  Bilal Elmoussaoui <bil.elmoussaoui@gnome.org>
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

private string render_duration (double duration) {
    int h;
    int m;
    int s;
    double r;
    Utils.time_to_hms (Math.floor (duration * 100) / 100, out h, out m, out s, out r);
    int cs = (int) (r * 10);
    return "%02i\u200E ∶ %02i\u200E ∶ %02i. %i".printf (h.abs (), m.abs (), s.abs (), cs.abs ());
}

public class Lap : GLib.Object {
    public int index; // Starts at #1
    public double duration;

    public Lap (int index, double duration) {
        this.index = index;
        this.duration = duration;
    }
}


[GtkTemplate (ui = "/org/gnome/clocks/ui/stopwatchlapsrow.ui")]
private class LapsRow : Gtk.ListBoxRow {
    [GtkChild]
    private Gtk.Label index_label;
    [GtkChild]
    private Gtk.Label difference_label;
    [GtkChild]
    private Gtk.Label duration_label;

    private Lap current;
    private Lap? before;

    public LapsRow (Lap current, Lap? before) {
        this.current = current;
        this.before = before;
        index_label.label = _("Lap %i").printf (this.current.index);
        duration_label.label = this.get_duration_label ();

        if (this.before != null) {
            difference_label.label = this.get_delta_label ();

            var difference = this.get_delta_duration ();
            if (difference > 0) {
                difference_label.get_style_context ().add_class ("negative-lap");
            } else if (difference < 0) {
                difference_label.get_style_context ().add_class ("positive-lap");
            }
        }
    }

    private string get_duration_label () {
        return render_duration (this.current.duration);
    }

    private double get_delta_duration () {
        if (this.before != null) {
            return this.current.duration - this.before.duration;
        }
        return 0;
    }

    private string? get_delta_label () {
        if (this.before != null) {
            var difference = this.current.duration - this.before.duration;
            var delta_label = render_duration (difference);
            string sign = "+";
            if (difference < 0) {
                sign = "-";
            }

            return "%s %s".printf (sign, delta_label);
        }
        return null;
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

    private ListStore laps;

    public string label { get; construct set; }
    public string icon_name { get; construct set; }
    public HeaderBar header_bar { get; construct set; }
    public PanelId panel_id { get; construct set; }
    public ButtonMode button_mode { get; set; default = NONE; }
    public ViewMode view_mode { get; set; default = NORMAL; }
    public bool can_select { get; set; default = false; }
    public bool n_selected { get; set; }
    public string title { get; set; default = _("Clocks"); }
    public string subtitle { get; set; }
    public string new_label { get; default = null; }

    public State state { get; private set; default = State.RESET; }

    private GLib.Timer timer;
    private uint tick_id;
    private int current_lap;

    [GtkChild]
    private Gtk.Label hours_label;
    [GtkChild]
    private Gtk.Label minutes_label;
    [GtkChild]
    private Gtk.Label seconds_label;
    [GtkChild]
    private Gtk.Label miliseconds_label;
    [GtkChild]
    private Gtk.Box time_container;

    [GtkChild]
    private Gtk.Revealer laps_revealer;

    [GtkChild]
    private Gtk.Button start_btn;
    [GtkChild]
    private Gtk.Button clear_btn;
    [GtkChild]
    private Gtk.ListBox laps_list;

    construct {
        panel_id = STOPWATCH;

        laps = new GLib.ListStore (typeof (Lap));

        timer = new GLib.Timer ();
        tick_id = 0;

        laps_list.set_header_func ((Gtk.ListBoxUpdateHeaderFunc) Hdy.list_box_separator_header);
        laps_list.bind_model (laps, (lap) => {
            var total_items = laps.get_n_items ();
            Lap? before = null;
            if (total_items > 1) {
                before = (Lap)laps.get_item (total_items - 1); // Get the latest item
            }
            var lap_row = new LapsRow ((Lap)lap, before);
            return lap_row;
        });

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
    private void on_start_btn_clicked (Gtk.Button button) {
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
    private void on_clear_btn_clicked (Gtk.Button button) {
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
        start_btn.set_label (_("Pause"));
        start_btn.get_style_context ().remove_class ("suggested-action");

        clear_btn.set_sensitive (true);
        clear_btn.set_label (_("Lap"));
        clear_btn.get_style_context ().remove_class ("destructive-action");

        time_container.get_style_context ().add_class ("running-stopwatch");
        time_container.get_style_context ().remove_class ("paused-stopwatch");
        time_container.get_style_context ().remove_class ("stopped-stopwatch");
    }

    private void stop () {
        timer.stop ();
        state = State.STOPPED;
        remove_tick ();
        start_btn.set_label (_("Resume"));
        start_btn.get_style_context ().remove_class ("destructive-action");
        start_btn.get_style_context ().add_class ("suggested-action");
        clear_btn.set_sensitive (true);
        clear_btn.set_label (_("Clear"));
        clear_btn.get_style_context ().add_class ("destructive-action");

        time_container.get_style_context ().add_class ("paused-stopwatch");
        time_container.get_style_context ().remove_class ("running-stopwatch");
        time_container.get_style_context ().remove_class ("stopped-stopwatch");
    }

    private void reset () {
        laps_revealer.set_reveal_child (false);

        timer.reset ();
        state = State.RESET;
        remove_tick ();
        update_time_label ();
        current_lap = 0;

        start_btn.set_label (_("Start"));
        start_btn.get_style_context ().add_class ("suggested-action");

        clear_btn.set_sensitive (false);
        clear_btn.set_label (_("Lap"));
        clear_btn.get_style_context ().remove_class ("destructive-action");

        time_container.get_style_context ().add_class ("stopped-stopwatch");
        time_container.get_style_context ().remove_class ("paused-stopwatch");
        time_container.get_style_context ().remove_class ("running-stopwatch");
        laps.remove_all ();
    }

    private double total_laps_duration () {
        double total = 0;
        for (var i = 0; i < laps.get_n_items (); i++) {
            var lap = (Lap) laps.get_item (i);
            total += lap.duration;
        }
        return total;
    }

    private void lap () {
        current_lap += 1;
        laps_revealer.reveal_child = current_lap >= 1;
        var e = timer.elapsed ();
        double lap_duration = e - this.total_laps_duration ();
        var lap = new Lap (current_lap, lap_duration);
        laps.insert (0, lap);
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
        hours_label.set_text ("%02i\u200E".printf (h));
        minutes_label.set_text ("%02i\u200E".printf (m));
        seconds_label.set_text ("%02i".printf (s));
        miliseconds_label.set_text ("%i".printf (ds));

        return true;
    }

    public override void grab_focus () {
        start_btn.grab_focus ();
    }

    public bool escape_pressed () {
        switch (state) {
        case State.RESET:
            return false;
        case State.STOPPED:
            reset ();
            break;
        case State.RUNNING:
            stop ();
            break;
        default:
            assert_not_reached ();
        }

        return true;
    }
}

} // namespace Stopwatch
} // namespace Clocks
