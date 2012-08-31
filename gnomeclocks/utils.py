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
import pycanberra
from xdg import BaseDirectory
from gi.repository import Gio, Notify


class Dirs:
    @staticmethod
    def get_data_dir():
        try:
            path = os.environ['GNOME_CLOCKS_DATA_PATH']
        except:
            path = "../data"
        return path

    @staticmethod
    def get_image_dir():
        try:
            path = os.environ['GNOME_CLOCKS_IMAGE_PATH']
        except:
            path = "../data"
        return path

    @staticmethod
    def get_locale_dir():
        try:
            path = os.environ['GNOME_CLOCKS_LOCALE_PATH']
        except:
            path = "locale"
        return path

    @staticmethod
    def get_user_data_dir():
        return BaseDirectory.save_data_path("gnome-clocks")


class SystemSettings:
    @staticmethod
    def get_clock_format():
        settings = Gio.Settings.new('org.gnome.desktop.interface')
        systemClockFormat = settings.get_string('clock-format')
        return systemClockFormat


class LocalizedWeekdays:
    MON = time.strftime("%a", (0, 0, 0, 0, 0, 0, 0, 0, 0))
    TUE = time.strftime("%a", (0, 0, 0, 0, 0, 0, 1, 0, 0))
    WED = time.strftime("%a", (0, 0, 0, 0, 0, 0, 2, 0, 0))
    THU = time.strftime("%a", (0, 0, 0, 0, 0, 0, 3, 0, 0))
    FRI = time.strftime("%a", (0, 0, 0, 0, 0, 0, 4, 0, 0))
    SAT = time.strftime("%a", (0, 0, 0, 0, 0, 0, 5, 0, 0))
    SUN = time.strftime("%a", (0, 0, 0, 0, 0, 0, 6, 0, 0))

    @staticmethod
    def get_list():
        return [
            LocalizedWeekdays.MON,
            LocalizedWeekdays.TUE,
            LocalizedWeekdays.WED,
            LocalizedWeekdays.THU,
            LocalizedWeekdays.FRI,
            LocalizedWeekdays.SAT,
            LocalizedWeekdays.SUN
        ]


class Alert:
    def __init__(self, soundid, msg, callback):
        try:
            self.canberra = pycanberra.Canberra()
        except Exception, e:
            print "Sound will not be available: ", e
            self.canberra = None

        self.soundid = soundid

        self.notification = None
        if Notify.is_initted() or Notify.init("GNOME Clocks"):
            self.notification = Notify.Notification.new("Clocks", msg, 'clocks')
            # the special "default" action should not display a button
            self.notification.add_action("default", "Show", callback, None, None)
        else:
            print "Error: Could not trigger Alert"

    def show(self):
        if self.canberra:
            self.canberra.play(1, pycanberra.CA_PROP_EVENT_ID, self.soundid, None)
        if self.notification:
            self.notification.show()

    def stop(self):
        if self.canberra:
            self.canberra.cancel(1)
