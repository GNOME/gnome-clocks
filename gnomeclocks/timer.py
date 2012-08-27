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

from gi.repository import Gtk, GObject, Gio
from clocks import Clock
from utils import Alert
from widgets import Spinner


class TimerScreen(Gtk.Box):
    def __init__(self, timer):
        super(TimerScreen, self).__init__()
        self.set_orientation(Gtk.Orientation.VERTICAL)
        self.timer = timer

        center = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)

        self.timerLabel = Gtk.Label()
        self.timerLabel.set_alignment(0.5, 0.5)
        self.timerLabel.set_markup(Timer.LABEL_MARKUP % (0, 0, 0))

        center.pack_start(Gtk.Label(""), False, True, 30)
        center.pack_start(self.timerLabel, False, True, 6)
        center.pack_start(Gtk.Label(""), False, True, 24)

        hbox = Gtk.Box()
        self.leftButton = Gtk.Button()
        self.leftButton.set_size_request(200, -1)
        self.leftLabel = Gtk.Label()
        self.leftButton.add(self.leftLabel)
        self.rightButton = Gtk.Button()
        self.rightButton.set_size_request(200, -1)
        self.rightLabel = Gtk.Label()
        self.rightButton.add(self.rightLabel)

        hbox.pack_start(self.leftButton, True, True, 0)
        hbox.pack_start(Gtk.Box(), True, True, 24)
        hbox.pack_start(self.rightButton, True, True, 0)

        self.leftLabel.set_markup(Timer.BUTTON_MARKUP % (_("Pause")))
        self.leftLabel.set_padding(6, 0)
        self.rightLabel.set_markup(Timer.BUTTON_MARKUP % (_("Reset")))
        self.rightLabel.set_padding(6, 0)

        self.leftButton.connect('clicked', self._on_left_button_clicked)
        self.rightButton.connect('clicked', self._on_right_button_clicked)

        self.pack_start(Gtk.Box(), False, False, 7)
        self.pack_start(center, False, False, 6)
        self.pack_start(hbox, False, False, 5)

    def set_time(self, h, m, s):
        self.timerLabel.set_markup(Timer.LABEL_MARKUP % (h, m, s))

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

        # FIXME: work around the fact that gtk does recalculate the label style
        # if the button class changes
        self.leftLabel.get_style_context().invalidate()


class TimerWelcomeScreen(Gtk.Box):
    def __init__(self, timer):
        super(TimerWelcomeScreen, self).__init__()
        self.timer = timer
        self.set_orientation(Gtk.Orientation.VERTICAL)

        center = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        bottom_spacer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)

        self.hours = Spinner(24, self)
        self.minutes = Spinner(59, self)
        self.seconds = Spinner(59, self)
        colon = Gtk.Label('')
        colon.set_markup('<span font_desc=\"64.0\">:</span>')
        another_colon = Gtk.Label('')
        another_colon.set_markup('<span font_desc=\"64.0\">:</span>')

        spinner = Gtk.Box()
        spinner.pack_start(self.hours, False, False, 0)
        spinner.pack_start(colon, False, False, 0)
        spinner.pack_start(self.minutes, False, False, 0)
        spinner.pack_start(another_colon, False, False, 0)
        spinner.pack_start(self.seconds, False, False, 0)

        #Start Button
        self.startButton = Gtk.Button()
        self.startButton.set_sensitive(False)
        self.startButton.set_size_request(200, -1)
        self.startLabel = Gtk.Label()
        self.startLabel.set_markup(Timer.BUTTON_MARKUP % (_("Start")))
        self.startLabel.set_padding(6, 0)
        self.startButton.add(self.startLabel)
        self.startButton.connect('clicked', self._on_start_clicked)
        bottom_spacer.pack_start(self.startButton, False, False, 0)

        center.pack_start(Gtk.Label(""), False, True, 16)
        center.pack_start(spinner, False, True, 5)
        center.pack_start(Gtk.Label(""), False, True, 3)

        self.pack_start(center, False, False, 6)
        self.pack_start(bottom_spacer, False, False, 6)

    def update_start_button_status(self):
        hours = self.hours.get_value()
        minutes = self.minutes.get_value()
        seconds = self.seconds.get_value()
        if hours == 0 and minutes == 0 and seconds == 0:
            self.startButton.set_sensitive(False)
            self.startButton.get_style_context().remove_class("clocks-go")
        else:
            self.startButton.set_sensitive(True)
            self.startButton.get_style_context().add_class("clocks-go")

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
        self.g_id = 0

        self.vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        box = Gtk.Box()
        self.add(box)
        box.pack_start(Gtk.Box(), True, True, 0)
        box.pack_start(self.vbox, False, False, 0)
        box.pack_end(Gtk.Box(), True, True, 0)

        self.timerbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.vbox.pack_start(Gtk.Box(), True, True, 0)
        self.vbox.pack_start(self.timerbox, False, False, 0)
        self.vbox.pack_start(Gtk.Box(), True, True, 0)
        self.vbox.pack_start(Gtk.Box(), True, True, 46)

        self.timer_welcome_screen = TimerWelcomeScreen(self)
        self.timer_screen = TimerScreen(self)
        self.show_timer_welcome_screen()

        self.alert = Alert("complete", "Ta Da !",
                           self._on_notification_activated)

    def _on_notification_activated(self, notif, action, data):
        win = self.get_toplevel()
        win.show_clock(self)

    def show_timer_welcome_screen(self):
        self.timerbox.pack_start(self.timer_welcome_screen, True, True, 0)
        self.timer_welcome_screen.update_start_button_status()

    def start_timer_screen(self):
        self.timerbox.remove(self.timer_welcome_screen)
        self.timerbox.pack_start(self.timer_screen, True, True, 0)
        self.timerbox.show_all()

    def end_timer_screen(self):
        self.timerbox.remove(self.timer_screen)
        self.show_timer_welcome_screen()
        self.timer_welcome_screen.hours.set_value(0)
        self.timer_welcome_screen.minutes.set_value(0)
        self.timer_welcome_screen.seconds.set_value(0)
        self.timer_welcome_screen.update_start_button_status()

    def start(self):
        if self.state == Timer.State.STOPPED and self.g_id == 0:
            hours = self.timer_welcome_screen.hours.get_value()
            minutes = self.timer_welcome_screen.minutes.get_value()
            seconds = self.timer_welcome_screen.seconds.get_value()
            self.timer_screen.set_time(hours, minutes, seconds)
            self.time = (hours * 60 * 60) + (minutes * 60) + seconds
            self.state = Timer.State.RUNNING
            self.g_id = GObject.timeout_add(1000, self.count)
            self.start_timer_screen()

    def reset(self):
        self.state = Timer.State.STOPPED
        self.end_timer_screen()
        if self.g_id != 0:
            GObject.source_remove(self.g_id)
        self.g_id = 0

    def pause(self):
        self.state = Timer.State.PAUSED
        GObject.source_remove(self.g_id)
        self.g_id = 0

    def cont(self):
        self.state = Timer.State.RUNNING
        self.g_id = GObject.timeout_add(1000, self.count)

    def count(self):
        self.time -= 1
        minutes, seconds = divmod(self.time, 60)
        hours, minutes = divmod(minutes, 60)

        self.timer_screen.set_time(hours, minutes, seconds)
        if hours == 00 and minutes == 00 and seconds == 00:
            self.alert.show()
            self.state = Timer.State.STOPPED
            self.timerbox.remove(self.timer_screen)
            self.show_timer_welcome_screen()
            if self.g_id != 0:
                GObject.source_remove(self.g_id)
            self.g_id = 0
            return False
        else:
            return True
