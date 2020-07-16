/*
 * Copyright (C) 2013  Paolo Borelli <pborelli@gnome.org>
 * Copyright (C) 2020  Zander Brown <zbrown@gnome.org>
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
namespace Alarm {

[GtkTemplate (ui = "/org/gnome/clocks/ui/alarm-row.ui")]
private class Row : Gtk.ListBoxRow {
    public Item alarm { get; construct set; }
    public Face face { get; construct set; }

    [GtkChild]
    private Gtk.Switch toggle;
    [GtkChild]
    private Gtk.Label title;
    [GtkChild]
    private Gtk.Revealer title_reveal;
    [GtkChild]
    private Gtk.Label time;
    [GtkChild]
    private Gtk.Label repeats;
    [GtkChild]
    private Gtk.Revealer repeats_reveal;

    public Row (Item alarm, Face face) {
        Object (alarm: alarm, face: face);

        alarm.notify["days"].connect (update_repeats);

        alarm.bind_property ("active", toggle, "active", SYNC_CREATE | BIDIRECTIONAL);

        alarm.notify["name"].connect (update);
        alarm.notify["active"].connect (update);
        alarm.notify["state"].connect (update);
        alarm.notify["time"].connect (update);

        update_repeats ();
        update ();
    }

    private void update_repeats () {
        repeats_reveal.reveal_child = !((Utils.Weekdays) alarm.days).empty;
        repeats.label = (string) alarm.days_label;
    }

    private void update () {
        if (alarm.active) {
            get_style_context ().add_class ("active");
        } else {
            get_style_context ().remove_class ("active");
        }

        if (alarm.state == Item.State.SNOOZING) {
            get_style_context ().add_class ("snoozing");
            time.label = alarm.snooze_time_label;
        } else {
            get_style_context ().remove_class ("snoozing");
            time.label = alarm.time_label;
        }

        var label = alarm.name;

        // Prior to 3.36 unamed alarms would just be called "Alarm",
        // pretend alarms called "Alarm" don't have a name (of course
        // this fails if the language/translation has since changed)
        if (alarm.name == _("Alarm")) {
            label = null;
        }

        if (alarm.state == Item.State.SNOOZING) {
            if (label != null && ((string) label).length > 0) {
                // Translators: The alarm for the time %s titled %s has been "snoozed"
                label = _("Snoozed from %s: %s").printf (alarm.time_label, (string) label);
            } else {
                // Translators: %s is a time
                label = _("Snoozed from %s").printf (alarm.time_label);
            }
        }

        title_reveal.reveal_child = label != null && ((string) label).length > 0;
        title.label = (string) label;
    }

    [GtkCallback]
    private void delete () {
        face.delete (alarm);
    }
}

} // namespace Alarm
} // namespace Clocks
