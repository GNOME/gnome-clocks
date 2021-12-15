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

[GtkTemplate (ui = "/org/gnome/clocks/ui/stopwatch-laps-row.ui")]
private class LapsRow : Gtk.ListBoxRow {
    [GtkChild]
    private unowned Gtk.Label index_label;
    [GtkChild]
    private unowned Gtk.Label difference_label;
    [GtkChild]
    private unowned Gtk.Label duration_label;

    private Lap current;
    private Lap? before;

    public LapsRow (Lap current, Lap? before) {
        this.current = current;
        this.before = before;
        index_label.label = _("Lap %i").printf (this.current.index);
        duration_label.label = this.get_duration_label ();

        if (this.before != null) {
            // So get_delta_label() can be null, but Vala doesn't
            // know that .label can be as well
            difference_label.label = (string) this.get_delta_label ();

            var difference = this.get_delta_duration ();
            if (difference > 0) {
                difference_label.add_css_class ("error");
            } else if (difference < 0) {
                difference_label.add_css_class ("accent");
            }
        }
    }

    private string get_duration_label () {
        return render_duration (this.current.duration);
    }

    private double get_delta_duration () {
        if (this.before != null) {
            return this.current.duration - ((Lap) this.before).duration;
        }
        return 0;
    }

    private string? get_delta_label () {
        if (this.before != null) {
            var difference = this.current.duration - ((Lap) this.before).duration;
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

} // namespace Stopwatch
} // namespace Clocks
