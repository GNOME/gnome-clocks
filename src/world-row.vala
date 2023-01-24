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
    public Item location { get; set; }

    [GtkChild]
    private unowned Gtk.Label time_label;
    [GtkChild]
    private unowned Gtk.Widget delete_button;

    [GtkChild]
    private unowned BindingGroup location_binds;

    internal signal void remove_clock ();

    construct {
        location_binds.bind ("city-name", this, "title", SYNC_CREATE);
        location_binds.bind_property ("day-label", this, "subtitle", SYNC_CREATE, (binding, src, ref target) => {
            var day_label = (string?) src;
            var message = Utils.get_time_difference_message ((double) location.local_offset);
            var subtitle = message;

            if (day_label != null && day_label != "") {
                subtitle = "%s • %s".printf ((string) day_label, message);
            } else if (location.automatic) {
                // Translators: This clock represents the local time
                subtitle = _("Current location");
            }

            target.set_string (subtitle);

            return true;
        });
        location_binds.bind ("time-label", time_label, "label", SYNC_CREATE);
        location_binds.bind_property ("automatic", delete_button, "sensitive", SYNC_CREATE, (binding, src, ref target) => {
            var is_automatic = (bool) src;

            target.set_boolean (!is_automatic);

            if (is_automatic) {
                delete_button.add_css_class ("hidden");
            } else {
                delete_button.remove_css_class ("hidden");
            }

            return true;
        });
        location_binds.bind_property ("sun-state", this, "css-classes", SYNC_CREATE, (binding, src, ref target) => {
            var current = css_classes;
            var updated = new Array<string> ();
            var state = (SunState) src;

            foreach (var css_class in current) {
                if (!(css_class in STATE_CLASSES)) {
                    updated.append_val (css_class);
                }
            }

            updated.append_val (state.as_css ());

            target.set_boxed (updated.steal ());

            return true;
        });
    }

    public Row (Item location) {
        Object (location: location);
    }

    [GtkCallback]
    private void delete () {
        remove_clock ();
    }
}

} // namespace World
} // namespace Clocks
