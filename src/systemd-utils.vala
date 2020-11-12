/*
 * Copyright (C) 2020 Purism SPC
 *
 * Authors:
 * Julian Sparber <julian@sparber.net>
 *
 * SPDX-License-Identifier: GPL-2.0+
 *
 */

namespace Clocks {
namespace SystemdUtils {

    [DBus (name = "org.freedesktop.systemd1.Manager")]
    interface Systemd1 : Object {
        public abstract void enable_unit_files (string[] files,
                                                bool runtime = false,
                                                bool force = false) throws GLib.Error;
        public abstract void disable_unit_files (string[] files,
                                                 bool runtime = false) throws GLib.Error;
        public abstract void start_unit (string name,
                                         string mode) throws GLib.Error;
        public abstract void stop_unit (string name,
                                        string mode) throws GLib.Error;
        public abstract void reload () throws GLib.Error;
    }

    private struct Times {
        int hour;
        int minute;
        Utils.Weekdays? days;
    }

    public class Timer : GLib.Object {
        private static Timer? instance;
        const string TIMER_FILE = Config.PACKAGE_NAME + Config.PROFILE + ".timer";
        const string SERVICE_FILE = Config.PACKAGE_NAME + Config.PROFILE + ".service";
        SList<Times?> times = new SList<Times?> ();
        bool in_progess = false;

        public static Timer get_default () {
          if (instance == null) {
            instance = new Timer ();
          }
          return (!) instance;
        }

        private Timer () {
          ensure_service ();
        }

        public void clear () {
          times = new SList<Times?> ();
        }

        public void add_time (int hour, int minute, Utils.Weekdays? days = null) {
            times.append ( {hour, minute, days } );
        }

        public async void commit () throws Error {
            if (in_progess)
                return;
            in_progess = true;
            File file = get_unit_file ();
            Systemd1 systemd1 = yield Bus.get_proxy (BusType.SESSION,
                                                     "org.freedesktop.systemd1",
                                                     "/org/freedesktop/systemd1");

            if ((SList<Times?>?) times != null) {
                debug ("Update .timer unit");
                FileOutputStream os = file.replace (null,
                                                    false,
                                                    FileCreateFlags.PRIVATE |
                                                    FileCreateFlags.REPLACE_DESTINATION);
                var builder = new StringBuilder ();
                builder.append ("[Unit]\n");
                builder.append ("Description=GNOME clocks timer\n");
                builder.append ("\n");
                builder.append ("[Timer]\n");
                builder.append ("Unit=gnome-clocks.service\n");
                builder.append (build_timers ());
                builder.append ("Persistent=true\n");
                builder.append ("\n");
                builder.append ("[Install]\n");
                builder.append ("WantedBy=default.target\n");
                os.write (builder.str.data);

                debug ("Enable and start .timer unit");
                systemd1.reload ();
                systemd1.enable_unit_files ({TIMER_FILE});
                systemd1.start_unit (TIMER_FILE, "replace");
            } else {
                if (file.query_exists ()) {
                    debug ("Stop and disable .timer unit");
                    systemd1.disable_unit_files ({TIMER_FILE});
                    systemd1.stop_unit (TIMER_FILE, "replace");

                    debug ("Delete .timer unit");
                    yield file.delete_async ();
                }
            }
            in_progess = false;
        }

        private string build_timers () {
            var builder = new StringBuilder ();
            times.foreach ( (t) => {
                if (t != null) {
                    var time = (!) t;
                    builder.append_printf ("OnCalendar=%s *-*-* %d:%d\n",
                                           get_enabled_days_string (time.days),
                                           time.hour, time.minute);
                }
            });
            return builder.str;
        }

        private static string get_enabled_days_string (Utils.Weekdays? days) {
            if (days == null || ((!) days).empty) {
                return "";
            }
            var builder = new StringBuilder ();
            var first = true;
            for (var day = 0; day < 7; day++) {
                if (((!)days).get (day)) {
                    if (!first)
                        builder.append (",");
                    else
                        first = false;
                    builder.append (get_day_string (day));
                }
            }
            return builder.str;
        }

        private static string get_day_string (Utils.Weekdays.Day day) {
            switch (day) {
                case Utils.Weekdays.Day.MON:
                    return "Mon";
                case Utils.Weekdays.Day.TUE:
                    return "Tue";
                case Utils.Weekdays.Day.WED:
                    return "Wed";
                case Utils.Weekdays.Day.THU:
                    return "Thu";
                case Utils.Weekdays.Day.FRI:
                    return "Fri";
                case Utils.Weekdays.Day.SAT:
                    return "Sat";
                case Utils.Weekdays.Day.SUN:
                    return "Sun";
                default:
                    return "";
            }
        }

        private File get_unit_file () {
            File file = File.new_build_filename (GLib.Environment.get_user_config_dir (),
                                                 "/systemd/user/",
                                                 TIMER_FILE);
            return file;
        }

        private void ensure_service () {
            File file = File.new_build_filename (GLib.Environment.get_user_config_dir (),
            "/systemd/user/",
            SERVICE_FILE);
            if (!file.query_exists ()) {
                debug ("Add new %s unit", SERVICE_FILE);
                try {
                    FileOutputStream os = file.create (FileCreateFlags.PRIVATE);
                    var builder = new StringBuilder ();
                    builder.append ("[Unit]\n");
                    builder.append ("Description=GNOME Clocks (simple clock application)\n");
                    builder.append ("\n");
                    builder.append ("[Service]\n");
                    builder.append ("Type=simple\n");
                    builder.append_printf ("ExecStart=%s/gnome-clocks\n", Config.BINDIR);
                    os.write (builder.str.data);
                } catch (Error error) {
                    warning ("Couldn't create systemd unit: %s", error.message);
                }
            }
        }
    }
}
}
