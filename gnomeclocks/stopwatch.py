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

import time
from gi.repository import Gtk, GObject
from clocks import Clock


class Stopwatch(Clock):
    LABEL_MARKUP = "<span font_desc=\"64.0\">%02i:%02i</span>"
    BUTTON_MARKUP = "<span font_desc=\"18.0\">%s</span>"

    class State:
        RESET = 0
        RUNNING = 1
        STOPPED = 2

    def __init__(self):
        Clock.__init__(self, _("Stopwatch"))

        self.state = Stopwatch.State.RESET
        self.timeout_id = 0
        self.start_time = 0
        self.time_diff = 0

        grid = Gtk.Grid()
        grid.set_halign(Gtk.Align.CENTER)
        grid.set_valign(Gtk.Align.CENTER)
        grid.set_row_spacing(48)
        grid.set_column_spacing(24)
        grid.set_column_homogeneous(True)
        self.add(grid)

        self.timeLabel = Gtk.Label()
        self.timeLabel.set_markup(Stopwatch.LABEL_MARKUP % (0, 0))
        # add margin to match the spinner size in the timer
        self.timeLabel.set_margin_top(42)
        self.timeLabel.set_margin_bottom(42)
        grid.attach(self.timeLabel, 0, 0, 2, 1)

        self.leftButton = Gtk.Button()
        self.leftButton.set_size_request(200, -1)
        self.leftLabel = Gtk.Label()
        self.leftLabel.set_markup(Stopwatch.BUTTON_MARKUP % (_("Start")))
        self.leftButton.add(self.leftLabel)
        self.leftButton.get_style_context().add_class("clocks-go")
        grid.attach(self.leftButton, 0, 1, 1, 1)

        self.rightButton = Gtk.Button()
        self.rightButton.set_size_request(200, -1)
        self.rightLabel = Gtk.Label()
        self.rightLabel.set_markup(Stopwatch.BUTTON_MARKUP % (_("Reset")))
        self.rightButton.add(self.rightLabel)
        self.rightButton.set_sensitive(False)
        grid.attach(self.rightButton, 1, 1, 1, 1)

        self.leftButton.connect("clicked", self._on_left_button_clicked)
        self.rightButton.connect("clicked", self._on_right_button_clicked)

    def _on_left_button_clicked(self, widget):
        if self.state in (Stopwatch.State.RESET, Stopwatch.State.STOPPED):
            self.state = Stopwatch.State.RUNNING
            self.start()
            self.leftLabel.set_markup(Stopwatch.BUTTON_MARKUP % (_("Stop")))
            self.leftButton.get_style_context().add_class("clocks-stop")
            self.rightButton.set_sensitive(True)
        elif self.state == Stopwatch.State.RUNNING:
            self.state = Stopwatch.State.STOPPED
            self.stop()
            self.leftLabel.set_markup(Stopwatch.BUTTON_MARKUP %
                (_("Continue")))
            self.rightLabel.set_markup(Stopwatch.BUTTON_MARKUP %
                (_("Reset")))
            self.leftButton.get_style_context().remove_class("clocks-stop")
            self.leftButton.get_style_context().add_class("clocks-go")

    def _on_right_button_clicked(self, widget):
        if self.state == Stopwatch.State.RUNNING:
            pass
        if self.state == Stopwatch.State.STOPPED:
            self.state = Stopwatch.State.RESET
            self.time_diff = 0
            self.leftLabel.set_markup(Stopwatch.BUTTON_MARKUP % (_("Start")))
            self.leftButton.get_style_context().add_class("clocks-go")
            #self.rightButton.get_style_context().add_class("clocks-lap")
            self.timeLabel.set_markup(Stopwatch.LABEL_MARKUP % (0, 0))
            self.rightButton.set_sensitive(False)

    def start(self):
        if self.timeout_id == 0:
            self.start_time = time.time()
            self.timeout_id = GObject.timeout_add(10, self.count)

    def stop(self):
        GObject.source_remove(self.timeout_id)
        self.timeout_id = 0
        self.time_diff = self.time_diff + (time.time() - self.start_time)

    def reset(self):
        self.time_diff = 0
        GObject.source_remove(self.timeout_id)
        self.timeout_id = 0

    def count(self):
        timediff = time.time() - self.start_time + self.time_diff
        elapsed_minutes, elapsed_seconds = divmod(timediff, 60)
        self.timeLabel.set_markup(Stopwatch.LABEL_MARKUP %
            (elapsed_minutes, elapsed_seconds))
        return True
