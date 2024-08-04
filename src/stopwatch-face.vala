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

[GtkTemplate (ui = "/org/gnome/clocks/ui/stopwatch-face.ui")]
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
    public string? new_label { get; default = null; }

    public State state { get; private set; default = State.RESET; }

    private GLib.Timer timer;
    private uint tick_id;
    private int stored_hour;
    private int stored_minute;
    private int stored_second;
    double stored_milisecond;
    private int current_lap;

    [GtkChild]
    private unowned Gtk.Label hours_label;
    [GtkChild]
    private unowned Gtk.Label minutes_label;
    [GtkChild]
    private unowned Gtk.Label seconds_label;
    [GtkChild]
    private unowned Gtk.Label miliseconds_label;
    [GtkChild]
    private unowned Gtk.Box time_container;

    [GtkChild]
    private unowned Gtk.Revealer laps_revealer;

    [GtkChild]
    private unowned Gtk.Box container;

    [GtkChild]
    private unowned Gtk.Button start_btn;
    [GtkChild]
    private unowned Gtk.Button clear_btn;
    [GtkChild]
    private unowned Gtk.ListBox laps_list;

    construct {
        panel_id = STOPWATCH;

        laps = new GLib.ListStore (typeof (Lap));

        timer = new GLib.Timer ();
        tick_id = 0;

        time_container.set_direction (Gtk.TextDirection.LTR);

        laps_list.bind_model (laps, (lap) => {
            var total_items = laps.get_n_items ();
            Lap? before = null;
            if (total_items > 1) {
                before = (Lap)laps.get_item (total_items - 1); // Get the latest item
            }
            var lap_row = new LapsRow ((Lap)lap, before);
            return lap_row;
        });

        laps.items_changed.connect (() => {
            if (laps.get_n_items () == 0) {
                this.container.valign = CENTER;
                this.container.margin_top = 0;
            } else {
                this.container.valign = FILL;
                this.container.margin_top = 36;
            }
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
            start_btn.grab_focus ();
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
        start_btn.set_label (_("_Pause"));
        start_btn.remove_css_class ("suggested-action");

        clear_btn.set_sensitive (true);
        clear_btn.set_label (_("_Lap"));
        clear_btn.remove_css_class ("destructive-action");

        time_container.add_css_class ("running-stopwatch");
        time_container.remove_css_class ("paused-stopwatch");
        time_container.remove_css_class ("stopped-stopwatch");
    }

    private void stop () {
        timer.stop ();
        state = State.STOPPED;
        remove_tick ();
        start_btn.set_label (_("R_esume"));
        start_btn.remove_css_class ("destructive-action");
        start_btn.add_css_class ("suggested-action");
        clear_btn.set_sensitive (true);
        clear_btn.set_label (_("_Clear"));
        clear_btn.add_css_class ("destructive-action");

        time_container.add_css_class ("paused-stopwatch");
        time_container.remove_css_class ("running-stopwatch");
        time_container.remove_css_class ("stopped-stopwatch");
    }

    private void reset () {
        laps_revealer.set_reveal_child (false);

        timer.reset ();
        state = State.RESET;
        remove_tick ();
        update_time_label ();
        current_lap = 0;

        start_btn.set_label (_("St_art"));
        start_btn.add_css_class ("suggested-action");

        clear_btn.set_sensitive (false);
        clear_btn.set_label (_("_Lap"));
        clear_btn.remove_css_class ("destructive-action");

        time_container.add_css_class ("stopped-stopwatch");
        time_container.remove_css_class ("paused-stopwatch");
        time_container.remove_css_class ("running-stopwatch");
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
        if (stored_hour != h) {
            hours_label.label = "%02i\u200E".printf (h);
            stored_hour = h;
        }
        if (stored_minute != m) {
            minutes_label.label = "%02i\u200E".printf (m);
            stored_minute = m;
        }
        if (stored_second != s) {
            seconds_label.label = "%02i".printf (s);
            stored_second = s;
        }
        if (stored_milisecond != ds) {
            miliseconds_label.label = "%i".printf (ds);
            stored_milisecond = ds;
        }

        return true;
    }

    public override bool grab_focus () {
        start_btn.grab_focus ();
        return true;
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

