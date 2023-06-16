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
public class Standalone : Adw.BreakpointBin {
    public string title { get; set; default = _("Clocks"); }
    public string subtitle { get; set; }
    public Item? location { get; set; }

    [GtkChild]
    private unowned Gtk.Label time_label;
    [GtkChild]
    private unowned Gtk.Label time_label_small;
    [GtkChild]
    private unowned Gtk.Label day_label;
    [GtkChild]
    private unowned Gtk.Label sunrise_label;
    [GtkChild]
    private unowned Gtk.Label sunset_label;

    [GtkChild]
    private unowned BindingGroup location_binds;

    construct {
        location_binds.bind ("country-name", this, "subtitle", SYNC_CREATE);
        location_binds.bind_property ("state-name", this, "title", SYNC_CREATE, (binding, src, ref target) => {
            var state_name = (string?) src;
            var title = location.city_name;

            if (state_name != null) {
                title = "%s, %s".printf (location.city_name, (string) state_name);
            }

            target.set_string (title);

            return true;
        });

        location_binds.bind ("time-label-seconds", time_label, "label", SYNC_CREATE);
        location_binds.bind ("time-label-seconds", time_label_small, "label", SYNC_CREATE);
        location_binds.bind ("day-label", day_label, "label", SYNC_CREATE);
        location_binds.bind ("sunrise-label", sunrise_label, "label", SYNC_CREATE);
        location_binds.bind ("sunset-label", sunset_label, "label", SYNC_CREATE);
    }
}

} // namespace World
} // namespace Clocks
