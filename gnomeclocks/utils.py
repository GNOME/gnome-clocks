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


class Alert:
    def __init__(self, soundid, msg, callback):
        self.canberra = pycanberra.Canberra()
        self.soundid = soundid

        self.notification = None
        if Notify.init("GNOME Clocks"):
            self.notification = Notify.Notification.new("Clocks", msg, 'clocks')
            # the special "default" action should not display a button
            self.notification.add_action("default", "Show", callback, None, None)
        else:
            print "Error: Could not trigger Alert"

    def show(self):
        self.canberra.play(1, pycanberra.CA_PROP_EVENT_ID, self.soundid, None)
        if self.notification:
            self.notification.show()
