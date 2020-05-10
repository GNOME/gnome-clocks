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
extern bool calculate_sunrise_sunset (double lat,
                                      double lon,
                                      int year,
                                      int month,
                                      int day,
                                      double correction,
                                      out int rise_hour,
                                      out int rise_min,
                                      out int set_hour,
                                      out int set_min);

const double RISESET_CORRECTION_NONE = 0.0;
const double RISESET_CORRECTION_CIVIL = 6.0;
const double RISESET_CORRECTION_NAUTICAL = 12.0;
const double RISESET_CORRECTION_ASTRONOMICAL = 18.0;

namespace Clocks {
namespace Utils {

public void load_css (string css) {
    var provider = new Gtk.CssProvider ();
    try {
        var data = resources_lookup_data ("/org/gnome/clocks/css/" + css + ".css", NONE);
        provider.load_from_data ((string) data.get_data ());
        Gtk.StyleContext.add_provider_for_screen ((Gdk.Screen) Gdk.Screen.get_default (),
                                                  provider,
                                                  Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
    } catch (ResourceError.NOT_FOUND e) {
        /* Ignore */
    } catch (Error e) {
        warning ("Didn't load css for %s: %s".printf (css, e.message));
    }
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

    private static WallClock? instance;

    public static WallClock get_default () {
        if (instance == null) {
            instance = new WallClock ();
        }
        // If it's still null something has gone horribly wrong
        return (WallClock) instance;
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
    private static string[]? abbreviations = null;
    private static string[]? names = null;

    public enum Day {
        MON = 0,
        TUE,
        WED,
        THU,
        FRI,
        SAT,
        SUN;

        private const string[] SYMBOLS = {
            // Translators: This is used in the repeat toggle for Monday
            NC_("Repeat|Monday", "M"),
            // Translators: This is used in the repeat toggle for Tuesday
            NC_("Repeat|Tuesday", "T"),
            // Translators: This is used in the repeat toggle for Wednesday
            NC_("Repeat|Wednesday", "W"),
            // Translators: This is used in the repeat toggle for Thursday
            NC_("Repeat|Thursday", "T"),
            // Translators: This is used in the repeat toggle for Friday
            NC_("Repeat|Friday", "F"),
            // Translators: This is used in the repeat toggle for Saturday
            NC_("Repeat|Saturday", "S"),
            // Translators: This is used in the repeat toggle for Sunday
            NC_("Repeat|Sunday", "S")
        };

        private const string[] PLURALS = {
            N_("Mondays"),
            N_("Tuesdays"),
            N_("Wednesdays"),
            N_("Thursdays"),
            N_("Fridays"),
            N_("Saturdays"),
            N_("Sundays")
        };

        public string symbol () {
            return _(SYMBOLS[this]);
        }

        public string plural () {
            return _(PLURALS[this]);
        }

        public string abbreviation () {
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
            return abbreviations[this];
        }

        public string name () {
            // lazy init because we cannot rely on class init being
            // called for us (at least in the current version of vala)
            if (names == null) {
                names = {
                     (new GLib.DateTime.utc (1, 1, 1, 0, 0, 0)).format ("%A"),
                     (new GLib.DateTime.utc (1, 1, 2, 0, 0, 0)).format ("%A"),
                     (new GLib.DateTime.utc (1, 1, 3, 0, 0, 0)).format ("%A"),
                     (new GLib.DateTime.utc (1, 1, 4, 0, 0, 0)).format ("%A"),
                     (new GLib.DateTime.utc (1, 1, 5, 0, 0, 0)).format ("%A"),
                     (new GLib.DateTime.utc (1, 1, 6, 0, 0, 0)).format ("%A"),
                     (new GLib.DateTime.utc (1, 1, 7, 0, 0, 0)).format ("%A"),
                };
            }
            return names[this];
        }

        public static Day get_first_weekday () {
            var d = clocks_cutils_get_week_start ();
            return (Day) ((d + 6) % 7);
        }
    }

    private const bool[] WEEKDAYS = {
        true, true, true, true, true, false, false
    };

    private const bool[] WEEKENDS = {
        false, false, false, false, false, true, true
    };

    const bool[] NONE = {
        false, false, false, false, false, false, false
    };

    const bool[] ALL = {
        true, true, true, true, true, true, true
    };

    private bool[] days = NONE;

    public bool empty {
        get {
            return (days_equal (NONE));
        }
    }

    public bool is_weekdays {
        get {
            return (days_equal (WEEKDAYS));
        }
    }

    public bool is_weekends {
        get {
            return (days_equal (WEEKENDS));
        }
    }

    public bool is_all {
        get {
            return (days_equal (ALL));
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
        string? r = null;
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
            r = ((Day) first).plural ();
        } else if (n == 7) {
            r = _("Every Day");
        } else if (days_equal (WEEKDAYS)) {
            r = _("Weekdays");
        } else if (days_equal (WEEKENDS)) {
            r = _("Weekends");
        } else {
            string?[]? abbrs = {};
            for (int i = 0; i < 7; i++) {
                Day d = (Day.get_first_weekday () + i) % 7;
                if (get (d)) {
                    abbrs += d.abbreviation ();
                }
            }
            r = string.joinv (", ", abbrs);
        }
        return (string) r;
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
        return builder.end ();
    }

    public static Weekdays deserialize (GLib.Variant days_variant) {
        Weekdays d = new Weekdays ();
        foreach (var v in days_variant) {
            var i = (int32) v;
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
    private GSound.Context? gsound;
    private GLib.Cancellable cancellable;
    private string soundtheme;
    private string sound;

    public Bell (string soundid) {
        try {
            gsound = new GSound.Context ();
        } catch (GLib.Error e) {
            warning ("Sound could not be initialized, error: %s", e.message);
        }

        var settings = new GLib.Settings ("org.gnome.desktop.sound");
        soundtheme = settings.get_string ("theme-name");
        sound = soundid;
        cancellable = new GLib.Cancellable ();
    }

    private async void ring_real (bool repeat) {
        if (gsound == null) {
            return;
        }

        if (cancellable.is_cancelled ()) {
            cancellable.reset ();
        }

        try {
            do {
                yield ((GSound.Context) gsound).play_full (cancellable,
                                                           GSound.Attribute.EVENT_ID, sound,
                                                           GSound.Attribute.CANBERRA_XDG_THEME_NAME, soundtheme,
                                                           GSound.Attribute.MEDIA_ROLE, "alarm");
            } while (repeat);
        } catch (GLib.IOError.CANCELLED e) {
            // ignore
        } catch (GLib.Error e) {
            warning ("Error playing sound: %s", e.message);
        }
    }

    public void ring_once () {
        ring_real.begin (false);
    }

    public void ring () {
        ring_real.begin (true);
    }

    public void stop () {
        cancellable.cancel ();
    }
}

} // namespace Utils
} // namespace Clocks
