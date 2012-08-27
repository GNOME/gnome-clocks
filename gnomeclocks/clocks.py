# Copyright(c) 2011-2012 Collabora, Ltd.
#
# Gnome Clocks is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by the
# Free Software Foundation; either version 2 of the License, or(at your
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

from gi.repository import GObject, Gtk


class Clock(Gtk.EventBox):
    __gsignals__ = {
        'show-requested': (GObject.SignalFlags.RUN_LAST,
                           None,
                           ()),
        'show-clock': (GObject.SignalFlags.RUN_LAST,
                       None,
                       (GObject.TYPE_PYOBJECT, )),
        'selection-changed': (GObject.SignalFlags.RUN_LAST,
                              None,
                              ())
    }

    def __init__(self, label, hasNew=False, hasSelectionMode=False):
        Gtk.EventBox.__init__(self)
        self.label = label
        self.hasNew = hasNew
        self.hasSelectionMode = hasSelectionMode
        self.get_style_context().add_class('view')
        self.get_style_context().add_class('content-view')

    def open_new_dialog(self):
        pass

    def get_selection(self):
        pass

    def unselect_all(self):
        pass

    def delete_selected(self):
        pass
