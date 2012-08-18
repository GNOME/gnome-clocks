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
from gi.repository import Gst, Notify

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


class Alert:
    def __init__(self):
        Gst.init('gst')

    def do_alert(self, msg):
        if Notify.init("GNOME Clocks"):
            Alert = Notify.Notification.new("Clocks", msg, 'test')
            Alert.show()
            playbin = Gst.ElementFactory.make('playbin', None)
            playbin.set_property('uri',
              'file:///usr/share/sounds/gnome/default/alerts/glass.ogg')
            playbin.set_state(Gst.State.PLAYING)
        else:
            print "Error: Could not trigger Alert"
