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

    [GtkChild]
    private unowned Gtk.Switch toggle;
    [GtkChild]
    private unowned Gtk.Label title;
    [GtkChild]
    private unowned Gtk.Revealer title_reveal;
    [GtkChild]
    private unowned Gtk.Label time;
    [GtkChild]
    private unowned Gtk.Label repeats;
    [GtkChild]
    private unowned Gtk.Revealer repeats_reveal;

    [GtkChild]
    private unowned BindingGroup alarm_binds;

    internal signal void remove_alarm ();

    construct {
        alarm_binds.bind ("active", toggle, "active", SYNC_CREATE | BIDIRECTIONAL);
        alarm_binds.bind ("days-label", repeats, "label", SYNC_CREATE);
        alarm_binds.bind_property ("days", repeats_reveal, "reveal-child", SYNC_CREATE, (binding, src, ref target) => {
            var days = (Utils.Weekdays) src;

            target.set_boolean (!days.empty);

            return true;
        });

        title.bind_property ("label", title_reveal, "reveal-child", SYNC_CREATE, (binding, src, ref target) => {
            var label = (string?) src;

            target.set_boolean (label != null && ((string) label).length > 0);

            return true;
        });
    }

    public Row (Item alarm) {
        Object (alarm: alarm);

        alarm.notify["name"].connect (update);
        alarm.notify["state"].connect (update);
        alarm.notify["time"].connect (update);
        alarm.notify["ring_time"].connect (update);

        update ();
    }

    private void update () {
        if (alarm.active) {
            add_css_class ("active");
        } else {
            remove_css_class ("active");
        }

        time.label = alarm.time_label;

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
                label = _("%s: Snoozed until %s").printf ((string) label, alarm.ring_time_label);
            } else {
                // Translators: %s is a time
                label = _("Snoozed until %s").printf (alarm.ring_time_label);
            }
        }

        if (alarm.state == Item.State.MISSED) {
            if (label != null && ((string) label).length > 0) {
                // Translators: The alarm titled %s was "missed"
                label = _("Alarm %s was missed").printf ((string) label);
            } else {
                label = _("Alarm was missed");
            }

            title.add_css_class ("error");
        } else {
            title.remove_css_class ("error");
        }

        title.label = (string) label;
    }

    [GtkCallback]
    private void delete () {
        remove_alarm ();
    }
}

} // namespace Alarm
} // namespace Clocks
