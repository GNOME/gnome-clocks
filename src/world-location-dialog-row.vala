/*
 * Copyright (C) 2020  Matyáš Hronek <saytamkenorh@seznam.cz>
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

[GtkTemplate (ui = "/org/gnome/clocks/ui/world-location-dialog-row.ui")]
private class LocationDialogRow : Gtk.ListBoxRow {
    public ClockLocation data { get; construct set; }

    public string? clock_name { get; set; default = null; }
    public string? clock_location { get; set; default = null; }
    public string? clock_description { get; set; default = null; }
    public bool clock_selected { get; set; default = false; }

    public LocationDialogRow (ClockLocation data) {
        Object (data: data);

        clock_name = data.location.get_name ();
        clock_location = data.location.get_country_name ();

        var wallclock = Utils.WallClock.get_default ();
        var local_time = wallclock.date_time;
        var time_zone = data.location.get_timezone ();
        if (time_zone != null) {
            var date_time = local_time.to_timezone (time_zone);
            var local_offset = local_time.get_utc_offset () - date_time.get_utc_offset ();
            var time_diff_message = Utils.get_time_difference_message (local_offset);
            // The time zone uses underscore instead of spaces.
            var time_zone_name = time_zone.get_identifier ().replace ("_", " ");

            if ((string?) time_zone_name != null) {
                clock_description = "%s • %s".printf (time_zone_name, time_diff_message);
            } else {
                clock_description = "%s".printf (time_diff_message);
            }
        } else {
            clock_description = null;
        }

        sensitive = !data.selected;

        data.bind_property ("selected", this, "clock-selected", SYNC_CREATE);
    }
}

} // namespace World
} // namespace Clocks
