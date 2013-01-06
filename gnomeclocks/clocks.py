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

from gi.repository import Gtk


class Clock(Gtk.Notebook):
    def __init__(self, label, toolbar, embed):
        Gtk.Notebook.__init__(self, show_tabs=False, show_border=False)
        self.show()
        self.label = label
        self._embed = embed
        self._toolbar = toolbar

        self.connect('map', self._ui_thaw)
        self.connect('unmap', self._ui_freeze)

    def insert_page(self, page, page_number):
        page.show_all()
        Gtk.Notebook.insert_page(self, page, None, page_number)

    def change_page(self, page_number):
        self.set_current_page(page_number)
        self.update_toolbar()

    def change_page_spotlight(self, page_number):
        self._embed.spotlight(lambda: self.change_page(page_number))

    def update_toolbar(self):
        """Updates the toolbar depending on the current clock page."""
        raise NotImplementedError

    def _ui_freeze(self, widget):
        """Called when the Clock widget is unmapped.

        Derived classes can implement this method to remove timeouts
        in order to save CPU time while the Clock widget is not
        visible."""
        pass

    def _ui_thaw(self, widget):
        """Called when the clock widget is mapped.

        Derived Clock classes can implement this method to re-add
        timeouts when the Clock widget becomes visible again."""
        pass
