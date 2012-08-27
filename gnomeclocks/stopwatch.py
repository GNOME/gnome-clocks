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
        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.add(vbox)

        center = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)

        self.stopwatchLabel = Gtk.Label()
        self.stopwatchLabel.set_alignment(0.5, 0.5)
        self.stopwatchLabel.set_markup(Stopwatch.LABEL_MARKUP % (0, 0))

        hbox = Gtk.Box()
        self.leftButton = Gtk.Button()
        self.leftButton.set_size_request(200, -1)
        self.leftLabel = Gtk.Label()
        self.leftButton.add(self.leftLabel)
        self.rightButton = Gtk.Button()
        self.rightButton.set_size_request(200, -1)
        self.rightLabel = Gtk.Label()
        self.rightButton.add(self.rightLabel)
        self.rightButton.set_sensitive(False)
        self.leftButton.get_style_context().add_class("clocks-go")
        #self.rightButton.get_style_context().add_class("clocks-lap")

        hbox.pack_start(Gtk.Box(), True, False, 0)
        hbox.pack_start(self.leftButton, False, False, 0)
        hbox.pack_start(Gtk.Box(), False, False, 24)
        hbox.pack_start(self.rightButton, False, False, 0)
        hbox.pack_start(Gtk.Box(), True, False, 0)

        self.leftLabel.set_markup(Stopwatch.BUTTON_MARKUP % (_("Start")))
        self.leftLabel.set_padding(6, 0)
        self.rightLabel.set_markup(Stopwatch.BUTTON_MARKUP % (_("Reset")))
        self.rightLabel.set_padding(6, 0)

        center.pack_start(self.stopwatchLabel, False, False, 0)
        center.pack_start(Gtk.Box(), True, True, 41)
        center.pack_start(hbox, False, False, 0)

        self.state = Stopwatch.State.RESET
        self.g_id = 0
        self.start_time = 0
        self.time_diff = 0

        vbox.pack_start(Gtk.Box(), True, True, 48)
        vbox.pack_start(center, False, False, 0)
        vbox.pack_start(Gtk.Box(), True, True, 1)
        vbox.pack_start(Gtk.Box(), True, True, 41)

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
            self.stopwatchLabel.set_markup(Stopwatch.LABEL_MARKUP % (0, 0))
            self.rightButton.set_sensitive(False)

    def start(self):
        if self.g_id == 0:
            self.start_time = time.time()
            self.g_id = GObject.timeout_add(10, self.count)

    def stop(self):
        GObject.source_remove(self.g_id)
        self.g_id = 0
        self.time_diff = self.time_diff + (time.time() - self.start_time)

    def reset(self):
        self.time_diff = 0
        GObject.source_remove(self.g_id)
        self.g_id = 0

    def count(self):
        timediff = time.time() - self.start_time + self.time_diff
        elapsed_minutes, elapsed_seconds = divmod(timediff, 60)
        self.stopwatchLabel.set_markup(Stopwatch.LABEL_MARKUP %
            (elapsed_minutes, elapsed_seconds))
        return True
