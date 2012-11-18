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

    def __init__(self, label, new_label=None, has_selection_mode=False):
        Gtk.EventBox.__init__(self)

        # We catch map/unmap here to allow pausing of expensive UI
        # updates, like for the stopwatch, when corresponding UI is not
        # visible.
        self.connect('map', self._ui_thaw)
        self.connect('unmap', self._ui_freeze)

        self.label = label
        self.new_label = new_label
        self.has_selection_mode = has_selection_mode
        self.get_style_context().add_class('view')
        self.get_style_context().add_class('content-view')

    @GObject.Signal
    def show_standalone(self):
        pass

    @GObject.Signal
    def selection_changed(self):
        pass

    def open_new_dialog(self):
        pass

    def get_selection(self):
        pass

    def unselect_all(self):
        pass

    def delete_selected(self):
        pass

    def _ui_freeze(self, widget):
        """
        Called when the clock widget is unmapped.

        Derived classes can implement this method to remove timeouts
        in order to save CPU time while the clock widget is not
        visible.
        """
        pass

    def _ui_thaw(self, widget):
        """
        Called when the clock widget is mapped.

        Derived clock classes can implement this method to re-add
        timeouts when the clock widget becomes visible again.
        """
        pass
