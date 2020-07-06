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
private class AddClockRow : Gtk.ListBoxRow {
    public ClockLocation data { get; construct set; }

    [GtkChild]
    private Gtk.Label name_label;
    [GtkChild]
    private Gtk.Label country_label;
    [GtkChild]
    private Gtk.Label desc;
    [GtkChild]
    private Gtk.Widget checkmark;

    public AddClockRow (ClockLocation data) {
        Object (data: data);

        name_label.label = data.location.get_name ();

        var country_name = data.location.get_country_name ();
        if (country_name != null) {
            country_label.label = (string) country_name;
        }

        var wallclock = Utils.WallClock.get_default ();
        var local_time = wallclock.date_time;
        var weather_time_zone = data.location.get_timezone ();
        if (weather_time_zone != null) {
            var time_zone = new TimeZone (((GWeather.Timezone) weather_time_zone).get_tzid ());
            var date_time = local_time.to_timezone (time_zone);
            var local_offset = local_time.get_utc_offset () - date_time.get_utc_offset ();
            var time_diff_message = Utils.get_time_difference_message (local_offset);
            var time_zone_name = ((GWeather.Timezone) weather_time_zone).get_name ();

            if ((string?) time_zone_name != null) {
                desc.label = "%s • %s".printf (time_zone_name, time_diff_message);
            } else {
                desc.label = "%s".printf (time_diff_message);
            }


        } else {
            desc.hide ();
        }

        sensitive = !data.selected;

        data.notify["selected"].connect (on_selected_changed);
    }

    private void on_selected_changed () {
        checkmark.visible = data.selected;
    }
}

} // namespace World
} // namespace Clocks
