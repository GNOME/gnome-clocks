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

extern int clocks_cutils_get_week_start ();

namespace Clocks {
namespace Utils {

public Gtk.CssProvider load_css (string css) {
    var provider = new Gtk.CssProvider ();
    try {
        var file = File.new_for_uri("resource:///org/gnome/clocks/css/" + css);
        provider.load_from_file (file);
    } catch (Error e) {
        warning ("loading css: %s", e.message);
    }
    return provider;
}

public Gtk.Builder load_ui (string ui) {
    var builder = new Gtk.Builder ();
    try {
        builder.add_from_resource ("/org/gnome/clocks/ui/".concat (ui, null));
    } catch (Error e) {
        error ("loading main builder file: %s", e.message);
    }
    return builder;
}

public Gdk.Pixbuf? load_image (string image) {
    try {
        var path = Path.build_filename (Config.DATADIR, "gnome-clocks", "images", image);
        return new Gdk.Pixbuf.from_file (path);
    } catch (Error e) {
        warning ("loading image file: %s", e.message);
    }
    return null;
}

public void time_to_hms (double t, out int h, out int m, out int s, out double remainder) {
    h = (int) t / 3600;
    t = t % 3600;
    m = (int) t / 60;
    t = t % 60;
    s = (int) t;
    remainder = t - s;
}

// TODO: For now we are wrapping Gnome's clock, but we should probably
// implement our own class, maybe using gnome-datetime-source
// Especially if we want to try to use CLOCK_REALTIME_ALARM
// see https://bugzilla.gnome.org/show_bug.cgi?id=686115
public class WallClock : Object {
    public enum Format {
        TWELVE,
        TWENTYFOUR
    }

    private static WallClock instance;

    public static WallClock get_default () {
        if (instance == null) {
            instance = new WallClock ();
        }
        return instance;
    }

    public GLib.DateTime date_time { get; private set; }
    public GLib.TimeZone timezone { get; private set; }
    public Format format { get; private set; }

    private GLib.Settings settings;
    private Gnome.WallClock wc;

    private WallClock () {
        wc = new Gnome.WallClock ();
        wc.notify["clock"].connect (() => {
            update ();
            tick ();
        });

        // mirror the wallclock's timezone property
        timezone = wc.timezone;
        wc.notify["timezone"].connect (() => {
            timezone = wc.timezone;
        });

        // system-wide settings about clock format
        settings = new GLib.Settings ("org.gnome.desktop.interface");
        settings.changed["clock-format"].connect (() => {
            update_format ();
        });
        update_format ();

        update ();
    }

    public signal void tick ();

    private void update_format () {
        var sys_format = settings.get_string ("clock-format");
        format = sys_format == "12h" ? Format.TWELVE : Format.TWENTYFOUR;
    }

    // provide various types/objects of the same time, to be used directly
    // in AlarmItem and ClockItem, so they don't need to call these
    // functions themselves all the time (they only care about minutes).
    private void update () {
        date_time = new GLib.DateTime.now (timezone);
    }

    public string format_time (GLib.DateTime date_time) {
        string time = date_time.format (format == Format.TWELVE ? "%I:%M %p" : "%H:%M");

        // Replace ":" with ratio, space with thin-space, and prepend LTR marker
        // to force direction. Replacement is done afterward because date_time.format
        // may fail with utf8 chars in some locales
        time = time.replace (":", "\xE2\x80\x8E\xE2\x88\xB6");

        if (format == Format.TWELVE) {
            time = time.replace (" ", "\xE2\x80\x89");
        }

        return time;
    }
}

public class Weekdays {
    public enum Day {
        MON,
        TUE,
        WED,
        THU,
        FRI,
        SAT,
        SUN
    }

    private const bool[] weekdays = {
        true, true, true, true, true, false, false
    };

    private const bool[] weekends = {
        false, false, false, false, false, true, true
    };

    private const string[] plurals = {
        N_("Mondays"),
        N_("Tuesdays"),
        N_("Wednesdays"),
        N_("Thursdays"),
        N_("Fridays"),
        N_("Saturdays"),
        N_("Sundays")
    };

    private static string[] abbreviations = null;

    public static Day get_first_weekday () {
        var d = clocks_cutils_get_week_start ();
        return (Day) ((d + 6) % 7);
    }

    public static string plural (Day d) {
        assert (d >= 0 && d < 7);
        return _(plurals[d]);
    }

    public static string abbreviation (Day d) {
        assert (d >= 0 && d < 7);

        // lazy init because we cannot rely on class init being
        // called for us (at least in the current version of vala)
        if (abbreviations == null) {
            abbreviations = {
                 (new GLib.DateTime.utc (1, 1, 1, 0, 0, 0)).format ("%a"),
                 (new GLib.DateTime.utc (1, 1, 2, 0, 0, 0)).format ("%a"),
                 (new GLib.DateTime.utc (1, 1, 3, 0, 0, 0)).format ("%a"),
                 (new GLib.DateTime.utc (1, 1, 4, 0, 0, 0)).format ("%a"),
                 (new GLib.DateTime.utc (1, 1, 5, 0, 0, 0)).format ("%a"),
                 (new GLib.DateTime.utc (1, 1, 6, 0, 0, 0)).format ("%a"),
                 (new GLib.DateTime.utc (1, 1, 7, 0, 0, 0)).format ("%a"),
            };
        }
        return abbreviations[d];
    }

    private bool[] days= {
        false, false, false, false, false, false, false
    };

    public Weekdays() {
    }

    public bool empty {
        get {
            return (days_equal ({false, false, false, false, false, false, false}));
        }
    }

    private bool days_equal (bool[] d) {
        assert (d.length == 7);
        return (Memory.cmp (d, days, days.length * sizeof (bool)) == 0);
    }

    public bool get (Day d) {
        assert (d >= 0 && d < 7);
        return days[d];
    }

    public void set (Day d, bool on) {
        assert (d >= 0 && d < 7);
        days[d] = on;
    }

    public string get_label () {
        string r = null;
        int n = 0;
        int first = -1;
        for (int i = 0; i < 7; i++) {
            if (get ((Day) i)) {
                if (first < 0) {
                    first = i;
                }
                n++;
            }
        }

        if (n == 0) {
            r = "";
        } else if (n == 1) {
            r = plural ((Day) first);
        } else if (n == 7) {
            r = _("Every Day");
        } else if (days_equal (weekdays)) {
            r = _("Weekdays");
        } else if (days_equal (weekends)) {
            r = _("Weekends");
        } else {
            string[] abbrs = {};
            for (int i = 0; i < 7; i++) {
                Day d = (get_first_weekday () + i) % 7;
                if (get (d)) {
                    abbrs += abbreviation (d);
                }
            }
            r = string.joinv (", ", abbrs);
        }
        return r;
    }

    // Note that we serialze days according to ISO 8601
    // (1 is Monday, 2 is Tuesday... 7 is Sunday)

    public GLib.Variant serialize () {
        var builder = new GLib.VariantBuilder (new VariantType ("ai"));
        int32 i = 1;
        foreach (var d in days) {
            if (d) {
                builder.add ("i", i);
            }
            i++;
        }
        return builder.end ();;
    }

    public static Weekdays deserialize (GLib.Variant days_variant) {
        Weekdays d = new Weekdays ();
        foreach (var v in days_variant) {
            int32 i = v.get_int32 ();
            if (i > 0 && i <= 7) {
                d.set ((Day) (i - 1), true);
            } else {
                warning ("Invalid days %d", i);
            }
        }
        return d;
    }
}

public class Bell : Object {
    private GLib.Settings settings;
    private Canberra.Context? canberra;
    private string soundtheme;
    private string sound;
    private GLib.Notification notification;

    public Bell (string soundid, string title, string msg) {
        settings = new GLib.Settings("org.gnome.desktop.sound");

        if (Canberra.Context.create (out canberra) < 0) {
            warning ("Sound will not be available");
            canberra = null;
        }

        soundtheme = settings.get_string ("theme-name");
        sound = soundid;

        notification = new GLib.Notification (title);
        notification.set_body (msg);
    }

    private bool keep_ringing () {
        Canberra.Proplist pl;
        Canberra.Proplist.create (out pl);
        pl.sets (Canberra.PROP_EVENT_ID, sound);
        pl.sets (Canberra.PROP_CANBERRA_XDG_THEME_NAME, soundtheme);
        pl.sets (Canberra.PROP_MEDIA_ROLE, "alarm");

        canberra.play_full (1, pl, (c, id, code) => {
            if (code == Canberra.SUCCESS) {
                GLib.Idle.add (keep_ringing);
            }
        });

        return false;
    }

    private void ring_real (bool once) {
        if (canberra != null) {
            if (once) {
                canberra.play (1,
                               Canberra.PROP_EVENT_ID, sound,
                               Canberra.PROP_CANBERRA_XDG_THEME_NAME, soundtheme,
                               Canberra.PROP_MEDIA_ROLE, "alarm");
            } else {
                GLib.Idle.add (keep_ringing);
            }
        }

        GLib.Application app = GLib.Application.get_default ();
        app.send_notification (null, notification);
    }

    public void ring_once () {
        ring_real (true);
    }

    public void ring () {
        ring_real (false);
    }

    public void stop () {
        if (canberra != null) {
            canberra.cancel (1);
        }
    }

    public void add_action (string label, string action) {
        notification.add_button (label, action);
    }
}

} // namespace Utils
} // namespace Clocks
