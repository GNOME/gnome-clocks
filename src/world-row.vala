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

[GtkTemplate (ui = "/org/gnome/clocks/ui/world-row.ui")]
private class Row : Adw.ActionRow {
    public Item location { get; construct set; }

    [GtkChild]
    private unowned Gtk.Label time_label;
    [GtkChild]
    private unowned Gtk.Widget delete_button;

    internal signal void remove_clock ();

    public Row (Item location) {
        Object (location: location);

        location.bind_property ("city-name", this, "title", BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE);
        location.tick.connect (update);

        update ();
    }

    private void update () {
        remove_css_class ("night");
        remove_css_class ("astro");
        remove_css_class ("naut");
        remove_css_class ("civil");
        remove_css_class ("day");
        add_css_class (location.state_class);

        var message = Utils.get_time_difference_message ((double) location.local_offset);

        if (location.day_label != null && location.day_label != "") {
            subtitle = "%s • %s".printf ((string) location.day_label, message);
            delete_button.sensitive = true;
            delete_button.remove_css_class ("hidden");
        } else if (location.automatic) {
            // Translators: This clock represents the local time
            subtitle = _("Current location");
            delete_button.sensitive = false;
            delete_button.add_css_class ("hidden");
        } else {
            subtitle = "%s".printf (message);
            delete_button.sensitive = true;
            delete_button.remove_css_class ("hidden");
        }

        time_label.label = location.time_label;
    }

    [GtkCallback]
    private void delete () {
        remove_clock ();
    }
}

} // namespace World
} // namespace Clocks
