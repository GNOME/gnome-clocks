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

[GtkTemplate (ui = "/org/gnome/clocks/ui/alarm-day-picker-row.ui")]
public class DayPickerRow : Adw.PreferencesRow {
    public bool monday {
        get {
            return days[Utils.Weekdays.Day.MON];
        }

        set {
            days[Utils.Weekdays.Day.MON] = value;
            update ();
        }
    }

    public bool tuesday {
        get {
            return days[Utils.Weekdays.Day.TUE];
        }

        set {
            days[Utils.Weekdays.Day.TUE] = value;
            update ();
        }
    }

    public bool wednesday {
        get {
            return days[Utils.Weekdays.Day.WED];
        }

        set {
            days[Utils.Weekdays.Day.WED] = value;
            update ();
        }
    }

    public bool thursday {
        get {
            return days[Utils.Weekdays.Day.THU];
        }

        set {
            days[Utils.Weekdays.Day.THU] = value;
            update ();
        }
    }

    public bool friday {
        get {
            return days[Utils.Weekdays.Day.FRI];
        }

        set {
            days[Utils.Weekdays.Day.FRI] = value;
            update ();
        }
    }

    public bool saturday {
        get {
            return days[Utils.Weekdays.Day.SAT];
        }

        set {
            days[Utils.Weekdays.Day.SAT] = value;
            update ();
        }
    }

    public bool sunday {
        get {
            return days[Utils.Weekdays.Day.SUN];
        }

        set {
            days[Utils.Weekdays.Day.SUN] = value;
            update ();
        }
    }

    public signal void days_changed ();

    private Utils.Weekdays days = new Utils.Weekdays ();

    [GtkChild]
    private unowned Gtk.Box box;

    construct {
        // Create actions to control propeties from menu items
        var group = new SimpleActionGroup ();
        group.add_action (new PropertyAction ("day-0", this, "monday"));
        group.add_action (new PropertyAction ("day-1", this, "tuesday"));
        group.add_action (new PropertyAction ("day-2", this, "wednesday"));
        group.add_action (new PropertyAction ("day-3", this, "thursday"));
        group.add_action (new PropertyAction ("day-4", this, "friday"));
        group.add_action (new PropertyAction ("day-5", this, "saturday"));
        group.add_action (new PropertyAction ("day-6", this, "sunday"));
        insert_action_group ("repeats", group);

        // Create an array with the weekday items with
        // buttons[0] referencing the button for Monday, and so on.
        var buttons = new Gtk.ToggleButton[7];
        for (int i = 0; i < 7; i++) {
            var day = (Utils.Weekdays.Day) i;
            buttons[i] = new Gtk.ToggleButton.with_label (day.symbol ());
            buttons[i].action_name = "repeats.day-%i".printf (i);
            buttons[i].tooltip_text = day.name ();
            buttons[i].add_css_class ("circular");
            buttons[i].halign = Gtk.Align.START;
        }

        // Add the items, starting with the first day of the week
        // depending on the locale.
        var first_weekday = Utils.Weekdays.Day.get_first_weekday ();
        for (int i = 0; i < 7; i++) {
            var day_number = (first_weekday + i) % 7;

            box.append (buttons[day_number]);
        }

        update ();
    }

    public void load (Utils.Weekdays current_days) {
        // Copy in the days
        for (int i = 0; i < 7; i++) {
            days[(Utils.Weekdays.Day) i] = current_days[(Utils.Weekdays.Day) i];
        }

        // Make sure the buttons update
        notify_property ("monday");
        notify_property ("tuesday");
        notify_property ("wednesday");
        notify_property ("thursday");
        notify_property ("friday");
        notify_property ("saturday");
        notify_property ("sunday");

        update ();
    }

    public Utils.Weekdays store () {
        var new_days = new Utils.Weekdays ();

        for (int i = 0; i < 7; i++) {
            new_days[(Utils.Weekdays.Day) i] = days[(Utils.Weekdays.Day) i];
        }

        return new_days;
    }

    private void update () {
        days_changed ();
    }
}

} // namespace Alarm
} // namespace Clocks
