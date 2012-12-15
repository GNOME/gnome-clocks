# Copyright (c) 2011-2012 Collabora, Ltd.
#
# Gnome Clocks is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by the
# Free Software Foundation; either version 2 of the License, or (at your
# option) any later version.
#
# Gnome Clocks is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public License along
# with Gnome Clocks; if not, write to the Free Software Foundation,
# Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#
# Author: Seif Lotfy <seif.lotfy@collabora.co.uk>

import os
import time
import datetime
import pycanberra
from gnomeclocks import GNOMECLOCKS_DATADIR
from xdg import BaseDirectory
from gi.repository import GObject, Gio, GnomeDesktop, Notify


def N_(message):
    return message


class Dirs:
    if os.path.exists(os.path.join("gnome-clocks.doap")):
        print "Running from a source checkout, loading local data"
        datadir = os.path.join("data")
    else:
        datadir = GNOMECLOCKS_DATADIR

    @staticmethod
    def get_css_dir():
        return os.path.join(Dirs.datadir, "css")

    @staticmethod
    def get_images_dir():
        return os.path.join(Dirs.datadir, "images")

    @staticmethod
    def get_user_data_dir():
        return BaseDirectory.save_data_path("gnome-clocks")


class SystemSettings:
    settings = Gio.Settings.new('org.gnome.desktop.interface')

    @staticmethod
    def get_clock_format():
        systemClockFormat = SystemSettings.settings.get_string('clock-format')
        return systemClockFormat


class TimeString:
    @staticmethod
    def format_time(t):
        if SystemSettings.get_clock_format() == "12h":
            fmt = "%I:%M %p"
        else:
            fmt = "%H:%M"

        # "datetime" has a strftime method, "time" des not
        if hasattr(t, 'strftime'):
            res = t.strftime(fmt)
        else:
            res = time.strftime(fmt, t)

        if res.startswith("0"):
            res = res[1:]
        return res


class LocalizedWeekdays:
    # translate them ourselves since we want plurals
    _plural = [
        N_("Mondays"),
        N_("Tuesdays"),
        N_("Wednesdays"),
        N_("Thursdays"),
        N_("Fridays"),
        N_("Saturdays"),
        N_("Sundays")
    ]

    # fetch abbreviations from libc
    _abbr = [
        time.strftime("%a", (0, 0, 0, 0, 0, 0, 0, 0, 0)),
        time.strftime("%a", (0, 0, 0, 0, 0, 0, 1, 0, 0)),
        time.strftime("%a", (0, 0, 0, 0, 0, 0, 2, 0, 0)),
        time.strftime("%a", (0, 0, 0, 0, 0, 0, 3, 0, 0)),
        time.strftime("%a", (0, 0, 0, 0, 0, 0, 4, 0, 0)),
        time.strftime("%a", (0, 0, 0, 0, 0, 0, 5, 0, 0)),
        time.strftime("%a", (0, 0, 0, 0, 0, 0, 6, 0, 0))
    ]

    @staticmethod
    def get_plural(day):
        return _(LocalizedWeekdays._plural[day])

    @staticmethod
    def get_abbr(day):
        return LocalizedWeekdays._abbr[day]

    # based on code from hamster-applet
    # pretty ugly, but it seems this is the only way
    # note that we use the convention used by struct_time.tm_wday
    # which is 0 = Monday, not the one used by strftime("%w")
    @staticmethod
    def first_weekday():
        try:
            process = os.popen("locale first_weekday week-1stday")
            week_offset, week_start = process.read().split('\n')[:2]
            process.close()
            week_start = datetime.date(*time.strptime(week_start, "%Y%m%d")[:3])
            week_offset = datetime.timedelta(int(week_offset) - 1)
            beginning = week_start + week_offset
            return (int(beginning.strftime("%w")) + 6) % 7
        except:
            return 0


class WallClock(GObject.GObject):
    _instance = None

    def __init__(self):
        if WallClock._instance:
            raise TypeError("Initialized twice")
        GObject.GObject.__init__(self)
        self._wc = GnomeDesktop.WallClock()
        self._wc.connect("notify::clock", self._on_notify_clock)
        self._update()

    def _on_notify_clock(self, *args):
        self._update()
        self.emit("time-changed")

    def _update(self):
        # provide various types/objects of the same time, to be used directly
        # in AlarmItem and ClockItem, so they don't need to call these
        # functions themselves all the time (they only care about minutes).
        self.time = time.time()
        self.localtime = time.localtime(self.time)
        self.datetime = datetime.datetime.fromtimestamp(self.time)

    @GObject.Signal
    def time_changed(self):
        pass

    @staticmethod
    def get_default():
        if WallClock._instance is None:
            WallClock._instance = WallClock()
        return WallClock._instance


class Alert:
    settings = Gio.Settings.new('org.gnome.desktop.sound')

    def __init__(self, soundid, title, msg):
        try:
            self.canberra = pycanberra.Canberra()
        except Exception as e:
            print "Sound will not be available: ", e
            self.canberra = None

        self.soundtheme = Alert.settings.get_string('theme-name')
        self.soundid = soundid

        self.notification = None
        if Notify.is_initted() or Notify.init("GNOME Clocks"):
            self.notification = Notify.Notification.new(title, msg, 'gnome-clocks')
        else:
            print "Error: Could not trigger Alert"

    def show(self):
        if self.canberra:
            self.canberra.play(1,
                               pycanberra.CA_PROP_EVENT_ID, self.soundid,
                               pycanberra.CA_PROP_CANBERRA_XDG_THEME_NAME, self.soundtheme,
                               pycanberra.CA_PROP_MEDIA_ROLE, "alarm",
                               None)
        if self.notification:
            self.notification.show()

    def stop(self):
        if self.canberra:
            self.canberra.cancel(1)
