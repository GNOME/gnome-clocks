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
from gi.repository import GLib,  GObject, Gtk
from clocks import Clock
from utils import Alert
from widgets import Spinner


class TimerScreen(Gtk.Grid):
    def __init__(self, timer, size_group):
        super(TimerScreen, self).__init__()
        self.timer = timer

        self.set_halign(Gtk.Align.CENTER)
        self.set_valign(Gtk.Align.CENTER)
        self.set_row_spacing(48)
        self.set_column_spacing(24)
        self.set_column_homogeneous(True)

        self.time_label = Gtk.Label()
        self.time_label.set_markup(Timer.LABEL_MARKUP % (0, 0, 0))
        size_group.add_widget(self.time_label)
        self.attach(self.time_label, 0, 0, 2, 1)

        self.left_button = Gtk.Button()
        self.left_button.set_size_request(200, -1)
        self.left_label = Gtk.Label()
        self.left_label.set_markup(Timer.BUTTON_MARKUP % (_("Pause")))
        self.left_button.add(self.left_label)
        self.attach(self.left_button, 0, 1, 1, 1)

        self.right_button = Gtk.Button()
        self.right_button.set_size_request(200, -1)
        self.right_label = Gtk.Label()
        self.right_label.set_markup(Timer.BUTTON_MARKUP % (_("Reset")))
        self.right_button.add(self.right_label)
        self.attach(self.right_button, 1, 1, 1, 1)

        self.left_button.connect("clicked", self._on_left_button_clicked)
        self.right_button.connect("clicked", self._on_right_button_clicked)

    def set_time(self, h, m, s):
        self.time_label.set_markup(Timer.LABEL_MARKUP % (h, m, s))

    def _on_right_button_clicked(self, data):
        self.left_label.set_markup(Timer.BUTTON_MARKUP % (_("Pause")))
        self.timer.reset()

    def _on_left_button_clicked(self, widget):
        if self.timer.state == Timer.State.RUNNING:
            self.timer.pause()
            self.left_label.set_markup(Timer.BUTTON_MARKUP % (_("Continue")))
            self.left_button.get_style_context().add_class("clocks-go")
        elif self.timer.state == Timer.State.PAUSED:
            self.timer.cont()
            self.left_label.set_markup(Timer.BUTTON_MARKUP % (_("Pause")))
            self.left_button.get_style_context().remove_class("clocks-go")


class TimerSetupScreen(Gtk.Grid):
    def __init__(self, timer, size_group):
        super(TimerSetupScreen, self).__init__()
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
        size_group.add_widget(spinner)
        self.attach(spinner, 0, 0, 1, 1)

        self.start_button = Gtk.Button()
        self.start_button.set_size_request(200, -1)
        label = Gtk.Label()
        label.set_markup(Timer.BUTTON_MARKUP % (_("Start")))
        self.start_button.set_sensitive(False)
        self.start_button.add(label)
        self.attach(self.start_button, 0, 1, 1, 1)

        self.start_button.connect('clicked', self._on_start_clicked)

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
            self.start_button.set_sensitive(False)
            self.start_button.get_style_context().remove_class("clocks-go")
        else:
            self.start_button.set_sensitive(True)
            self.start_button.get_style_context().add_class("clocks-go")

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

        # force the time label and the spinner to the same size
        size_group = Gtk.SizeGroup(Gtk.SizeGroupMode.VERTICAL);

        self.setup_screen = TimerSetupScreen(self, size_group)
        self.notebook.append_page(self.setup_screen, None)

        self.timer_screen = TimerScreen(self, size_group)
        self.notebook.append_page(self.timer_screen, None)

        self.show_all()

        self.alert = Alert("complete", "Ta Da !")

        self._ui_is_frozen = False

    @GObject.Signal
    def alarm_ringing(self):
        self.alert.show()

    def show_setup_screen(self, reset):
        self.notebook.set_current_page(0)
        if reset:
            self.setup_screen.set_values(0, 0, 0)

    def show_timer_screen(self):
        self.notebook.set_current_page(1)

    def _add_timeout(self):
        if self.timeout_id == 0:
            self.timeout_id = GLib.timeout_add(250, self.count)

    def _remove_timeout(self):
        if self.timeout_id != 0:
            GLib.source_remove(self.timeout_id)
        self.timeout_id = 0

    def start(self):
        if self.state == Timer.State.STOPPED and self.timeout_id == 0:
            h, m, s = self.setup_screen.get_values()
            self.timer_screen.set_time(h, m, s)
            self.duration = (h * 60 * 60) + (m * 60) + s
            self.deadline = time.time() + self.duration
            self.state = Timer.State.RUNNING
            self._add_timeout()
            self.show_timer_screen()

    def reset(self):
        self.state = Timer.State.STOPPED
        self._remove_timeout()
        self.show_setup_screen(True)

    def pause(self):
        self.duration = self.deadline - time.time()
        self.state = Timer.State.PAUSED
        self._remove_timeout()

    def cont(self):
        self.deadline = time.time() + self.duration
        self.state = Timer.State.RUNNING
        self._add_timeout()

    def count(self):
        t = time.time()
        if t >= self.deadline:
            self.emit("alarm-ringing")
            self.state = Timer.State.STOPPED
            self._remove_timeout()
            self.timer_screen.set_time(0, 0, 0)
            self.show_setup_screen(False)
            return False
        elif self._ui_is_frozen == False:
            r = self.deadline - t
            m, s = divmod(r, 60)
            h, m = divmod(m, 60)
            self.timer_screen.set_time(h, m, s)
        return True

    def _ui_freeze(self, widget):
        self._ui_is_frozen = True

    def _ui_thaw(self, widget):
        self._ui_is_frozen = False
        self.count
