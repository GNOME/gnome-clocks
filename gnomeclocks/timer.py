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
from gi.repository import GObject, Gtk
from clocks import Clock
from utils import Alert
from widgets import Spinner


class TimerScreen(Gtk.Grid):
    def __init__(self, timer):
        super(TimerScreen, self).__init__()
        self.timer = timer

        self.set_halign(Gtk.Align.CENTER)
        self.set_valign(Gtk.Align.CENTER)
        self.set_row_spacing(48)
        self.set_column_spacing(24)
        self.set_column_homogeneous(True)

        self.timeLabel = Gtk.Label()
        self.timeLabel.set_markup(Timer.LABEL_MARKUP % (0, 0, 0))
        # add margin to match the spinner size
        self.timeLabel.set_margin_top(42)
        self.timeLabel.set_margin_bottom(42)
        self.attach(self.timeLabel, 0, 0, 2, 1)

        self.leftButton = Gtk.Button()
        self.leftButton.set_size_request(200, -1)
        self.leftLabel = Gtk.Label()
        self.leftLabel.set_markup(Timer.BUTTON_MARKUP % (_("Pause")))
        self.leftButton.add(self.leftLabel)
        self.attach(self.leftButton, 0, 1, 1, 1)

        self.rightButton = Gtk.Button()
        self.rightButton.set_size_request(200, -1)
        self.rightLabel = Gtk.Label()
        self.rightLabel.set_markup(Timer.BUTTON_MARKUP % (_("Reset")))
        self.rightButton.add(self.rightLabel)
        self.attach(self.rightButton, 1, 1, 1, 1)

        self.leftButton.connect("clicked", self._on_left_button_clicked)
        self.rightButton.connect("clicked", self._on_right_button_clicked)

    def set_time(self, h, m, s):
        self.timeLabel.set_markup(Timer.LABEL_MARKUP % (h, m, s))

    def _on_right_button_clicked(self, data):
        self.leftLabel.set_markup(Timer.BUTTON_MARKUP % (_("Pause")))
        self.timer.reset()

    def _on_left_button_clicked(self, widget):
        if self.timer.state == Timer.State.RUNNING:
            self.timer.pause()
            self.leftLabel.set_markup(Timer.BUTTON_MARKUP % (_("Continue")))
            self.leftButton.get_style_context().add_class("clocks-go")
        elif self.timer.state == Timer.State.PAUSED:
            self.timer.cont()
            self.leftLabel.set_markup(Timer.BUTTON_MARKUP % (_("Pause")))
            self.leftButton.get_style_context().remove_class("clocks-go")


class TimerWelcomeScreen(Gtk.Grid):
    def __init__(self, timer):
        super(TimerWelcomeScreen, self).__init__()
        self.timer = timer

        self.set_halign(Gtk.Align.CENTER)
        self.set_valign(Gtk.Align.CENTER)
        self.set_row_spacing(48)

        self.hours = Spinner(0, 24)
        self.minutes = Spinner(0, 59)
        self.seconds = Spinner(0, 59)

        self.hours.connect("value-changed", self._on_spinner_changed)
        self.minutes.connect("value-changed", self._on_spinner_changed)
        self.seconds.connect("value-changed", self._on_spinner_changed)

        spinner = Gtk.Box()
        spinner.pack_start(self.hours, False, False, 0)
        colon = Gtk.Label()
        colon.set_markup('<span font_desc=\"64.0\">:</span>')
        spinner.pack_start(colon, False, False, 0)
        spinner.pack_start(self.minutes, False, False, 0)
        colon = Gtk.Label()
        colon.set_markup('<span font_desc=\"64.0\">:</span>')
        spinner.pack_start(colon, False, False, 0)
        spinner.pack_start(self.seconds, False, False, 0)
        self.attach(spinner, 0, 0, 1, 1)

        self.startButton = Gtk.Button()
        self.startButton.set_size_request(200, -1)
        self.startLabel = Gtk.Label()
        self.startLabel.set_markup(Timer.BUTTON_MARKUP % (_("Start")))
        self.startButton.set_sensitive(False)
        self.startButton.add(self.startLabel)
        self.attach(self.startButton, 0, 1, 1, 1)

        self.startButton.connect('clicked', self._on_start_clicked)

    def get_values(self):
        h = self.hours.get_value()
        m = self.minutes.get_value()
        s = self.seconds.get_value()
        return (h, m, s)

    def set_values(self, h, m, s):
        self.hours.set_value(h)
        self.minutes.set_value(m)
        self.seconds.set_value(s)
        self.update_start_button_status()

    def update_start_button_status(self):
        h, m, s = self.get_values()
        if h == 0 and m == 0 and s == 0:
            self.startButton.set_sensitive(False)
            self.startButton.get_style_context().remove_class("clocks-go")
        else:
            self.startButton.set_sensitive(True)
            self.startButton.get_style_context().add_class("clocks-go")

    def _on_spinner_changed(self, spinner):
        self.update_start_button_status()

    def _on_start_clicked(self, data):
        self.timer.start()


class Timer(Clock):
    LABEL_MARKUP = "<span font_desc=\"64.0\">%02i:%02i:%02i</span>"
    BUTTON_MARKUP = "<span font_desc=\"18.0\">% s</span>"

    class State:
        STOPPED = 0
        RUNNING = 1
        PAUSED = 2

    def __init__(self):
        Clock.__init__(self, _("Timer"))
        self.state = Timer.State.STOPPED
        self.timeout_id = 0

        self.notebook = Gtk.Notebook()
        self.notebook.set_show_tabs(False)
        self.notebook.set_show_border(False)
        self.add(self.notebook)

        self.welcome_screen = TimerWelcomeScreen(self)
        self.notebook.append_page(self.welcome_screen, None)

        self.timer_screen = TimerScreen(self)
        self.notebook.append_page(self.timer_screen, None)

        self.alert = Alert("complete", "Ta Da !",
                           self._on_notification_activated)

    def _on_notification_activated(self, notif, action, data):
        win = self.get_toplevel()
        win.show_clock(self)

    def show_welcome_screen(self, reset):
        self.notebook.set_current_page(0)
        if reset:
            self.welcome_screen.set_values(0, 0, 0)

    def show_timer_screen(self):
        self.notebook.set_current_page(1)

    def _add_timeout(self):
        self.timeout_id = GObject.timeout_add(250, self.count)

    def _remove_timeout(self):
        if self.timeout_id != 0:
            GObject.source_remove(self.timeout_id)
        self.timeout_id = 0

    def start(self):
        if self.state == Timer.State.STOPPED and self.timeout_id == 0:
            h, m, s = self.welcome_screen.get_values()
            self.timer_screen.set_time(h, m, s)
            self.deadline = time.time() + (h * 60 * 60) + (m * 60) + s
            self.state = Timer.State.RUNNING
            self._add_timeout()
            self.show_timer_screen()

    def reset(self):
        self.state = Timer.State.STOPPED
        self._remove_timeout()
        self.show_welcome_screen(True)

    def pause(self):
        self.state = Timer.State.PAUSED
        self._remove_timeout()

    def cont(self):
        self.state = Timer.State.RUNNING
        self._add_timeout()

    def count(self):
        t = time.time()
        if t >= self.deadline:
            self.alert.show()
            self.state = Timer.State.STOPPED
            self._remove_timeout()
            self.timer_screen.set_time(0, 0, 0)
            self.show_welcome_screen(False)
            return False
        else:
            r = self.deadline - t
            m, s = divmod(r, 60)
            h, m = divmod(m, 60)
            self.timer_screen.set_time(h, m, s)
            return True
