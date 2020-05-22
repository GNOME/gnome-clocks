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

[GtkTemplate (ui = "/org/gnome/clocks/ui/world-location-dialog.ui")]
private class LocationDialog : Gtk.Dialog {
    [GtkChild]
    private GWeather.LocationEntry location_entry;
    private Face world;

    public LocationDialog (Gtk.Window parent, Face world_face) {
        Object (transient_for: parent, use_header_bar: 1);

        world = world_face;
    }

    [GtkCallback]
    private void icon_released () {
        if (location_entry.secondary_icon_name == "edit-clear-symbolic") {
            location_entry.set_text ("");
        }
    }

    [GtkCallback]
    private void location_changed () {
        GWeather.Location? l = null;
        GWeather.Timezone? t = null;

        if (location_entry.get_text () != "") {
            l = location_entry.get_location ();

            if (l != null && !world.location_exists ((GWeather.Location) l)) {
                t = ((GWeather.Location) l).get_timezone ();

                if (t == null) {
                    warning ("Timezone not defined for %s. This is a bug in libgweather database",
                             (string) ((GWeather.Location) l).get_city_name ());
                }
            }
        }

        set_response_sensitive (1, l != null && t != null);
    }

    public Item? get_location () {
        var location = location_entry.get_location ();
        return location != null ? (Item?) new Item ((GWeather.Location) location) : null;
    }
}

} // namespace World
} // namespace Clocks
