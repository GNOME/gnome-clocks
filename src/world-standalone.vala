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
namespace World {

[GtkTemplate (ui = "/org/gnome/clocks/ui/world-standalone.ui")]
public class Standalone : Gtk.Box {
    public string title { get; set; default = _("Clocks"); }
    public string subtitle { get; set; }
    public Item? location { get; set; }

    [GtkChild]
    private Gtk.Label time_label;
    [GtkChild]
    private Gtk.Label day_label;
    [GtkChild]
    private Gtk.Label sunrise_label;
    [GtkChild]
    private Gtk.Label sunset_label;

    construct {
        // Start ticking...
        Utils.WallClock.get_default ().tick.connect (update);
    }

    private void update () {
        if (location != null) {
            time_label.label = ((Item) location).time_label;
            day_label.label = (string) ((Item) location).day_label;
            sunrise_label.label = ((Item) location).sunrise_label;
            sunset_label.label = ((Item) location).sunset_label;
        }
    }

    [GtkCallback]
    private void location_changed () {
        if (location == null) {
            return;
        }

        update ();

        var item = (Item) location;

        if (item.state_name != null) {
            title = "%s, %s".printf (item.city_name, (string) item.state_name);
        } else {
            title = item.city_name;
        }

        subtitle = (string) item.country_name;
    }
}

} // namespace World
} // namespace Clocks
