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

from gi.repository import Gtk, Gio, Gdk

TIMER = "<span font_desc=\"64.0\">%02i</span>"
TIMER_LABEL_MARKUP = "<span font_desc=\"64.0\">%02i:%02i:%02i</span>"
TIMER = "<span font_desc=\"64.0\">%02i</span>"
TIMER_BUTTON_MARKUP = "<span font_desc=\"24.0\">%s</span>"


class Spinner(Gtk.Box):
    def __init__(self, max_value, timer_welcome_screen):
        super(Spinner, self).__init__()
        self.max_value = max_value
        self.timer_welcome_screen = timer_welcome_screen
        self.set_orientation(Gtk.Orientation.VERTICAL)
        iconUp = Gio.ThemedIcon.new_with_default_fallbacks ("go-up-symbolic")
        iconDown = Gio.ThemedIcon.new_with_default_fallbacks ("go-down-symbolic")
        imageUp = Gtk.Image.new_from_gicon(iconUp, Gtk.IconSize.DND)
        imageDown = Gtk.Image.new_from_gicon(iconDown, Gtk.IconSize.DND)
        #Up Button
        self.up = Gtk.Button()
        self.up.set_image(imageUp)
        self.up.set_relief(Gtk.ReliefStyle.NONE)
        #Value
        self.value = Gtk.Label('')
        self.value.set_markup(TIMER%(0))
        self.value.set_alignment (0.5, 0.5)
        #Down Button
        self.down = Gtk.Button()
        self.down.set_image(imageDown)
        self.down.set_relief(Gtk.ReliefStyle.NONE)
        #
        self.pack_start(self.up, False, False, 0)
        self.pack_start(self.value, True, True, 0)
        self.pack_start(self.down, False, False, 0)
        #Signals
        self.up.connect('clicked', self._increase)
        self.down.connect('clicked', self._decrease)

    def get_value(self):
        return int(self.value.get_text())

    def set_value(self, newValue):
        self.value.set_markup(TIMER%(newValue))

    def _increase(self, widget):
        value = self.get_value()
        if value == self.max_value:
            value = 0
        else:
            value += 1
        self.set_value(value)
        self.timer_welcome_screen.update_start_button_status()

    def _decrease(self, widget):
        value = self.get_value()
        if value == 0:
            value = self.max_value
        else:
            value -= 1
        self.set_value(value)
        self.timer_welcome_screen.update_start_button_status()


class TimerScreen (Gtk.Box):
    def __init__(self, timer):
        super(TimerScreen, self).__init__()
        self.set_orientation(Gtk.Orientation.VERTICAL)
        self.timer = timer

        top_spacer = Gtk.Box ()
        center = Gtk.Box (orientation=Gtk.Orientation.VERTICAL)
        bottom_spacer = Gtk.Box (orientation=Gtk.Orientation.VERTICAL)

        self.timerLabel = Gtk.Label ()
        self.timerLabel.set_alignment (0.5, 0.5)
        self.timerLabel.set_markup (TIMER_LABEL_MARKUP%(0,0,0))

        center.pack_start (Gtk.Label (""), False, True, 30)
        center.pack_start (self.timerLabel, False, True, 6)
        center.pack_start (Gtk.Label (""), False, True, 24)

        hbox = Gtk.Box()
        self.leftButton = Gtk.Button ()
        self.leftButton.set_size_request(200, -1)
        self.leftLabel = Gtk.Label ()
        self.leftButton.add (self.leftLabel)
        self.rightButton = Gtk.Button ()
        self.rightButton.set_size_request(200, -1)
        self.rightLabel = Gtk.Label ()
        self.rightButton.add (self.rightLabel)

        hbox.pack_start (self.leftButton, True, True, 0)
        hbox.pack_start (Gtk.Box(), True, True, 24)
        hbox.pack_start (self.rightButton, True, True, 0)

        self.leftLabel.set_markup(TIMER_BUTTON_MARKUP % (_("Pause")))
        self.leftLabel.set_padding (6, 0)
        self.rightLabel.set_markup(TIMER_BUTTON_MARKUP % (_("Reset")))
        self.rightLabel.set_padding (6, 0)

        self.leftButton.connect('clicked', self._on_left_button_clicked)
        self.rightButton.connect('clicked', self._on_right_button_clicked)

        self.pack_start(Gtk.Box (), False, False, 7)
        self.pack_start(center, False, False, 6)
        self.pack_start(hbox, False, False, 5)

    def _on_right_button_clicked(self, data):
        self.timer.reset()

    def _on_left_button_clicked(self, widget):
        if self.timer.state == 1:
            self.timer.pause()
            self.leftLabel.set_markup(TIMER_BUTTON_MARKUP % (_("Continue")))
            self.leftButton.get_style_context ().add_class ("clocks-go")
        elif self.timer.state == 2:
            self.timer.cont()
            self.leftLabel.set_markup(TIMER_BUTTON_MARKUP % (_("Pause")))
            self.leftButton.get_style_context ().remove_class ("clocks-go")

        # FIXME: work around the fact that gtk does recalculate the label style
        # if the button class changes
        self.leftLabel.get_style_context ().invalidate ()

class TimerWelcomeScreen (Gtk.Box):
    def __init__ (self, timer):
        super(TimerWelcomeScreen, self).__init__ ()
        self.timer = timer
        self.set_orientation(Gtk.Orientation.VERTICAL)

        top_spacer = Gtk. Box ()
        center = Gtk.Box (orientation=Gtk.Orientation.VERTICAL)
        bottom_spacer = Gtk.Box (orientation=Gtk.Orientation.VERTICAL) #Contains Start Button

        self.hours = Spinner(24, self)
        self.minutes = Spinner(59, self)
        self.seconds = Spinner(59, self)
        colon = Gtk.Label('')
        colon.set_markup('<span font_desc=\"64.0\">:</span>')
        another_colon = Gtk.Label('')
        another_colon.set_markup('<span font_desc=\"64.0\">:</span>')

        spinner = Gtk.Box () #Contains 3 columns to set the time
        spinner.pack_start(self.hours, False, False, 0)
        spinner.pack_start(colon, False, False, 0)
        spinner.pack_start(self.minutes, False, False, 0)
        spinner.pack_start(another_colon, False, False, 0)
        spinner.pack_start(self.seconds, False, False, 0)

        #Start Button
        self.startButton = Gtk.Button()
        self.startButton.set_sensitive(False)
        self.startButton.set_size_request(200, -1)
        self.startButton.get_style_context ().add_class ("clocks-go")
        self.startLabel = Gtk.Label()
        self.startLabel.set_markup(TIMER_BUTTON_MARKUP % (_("Start")))
        self.startLabel.set_padding (6, 0)
        self.startButton.add(self.startLabel)
        self.startButton.connect('clicked', self._on_start_clicked)
        bottom_spacer.pack_start (self.startButton, False, False, 0)

        center.pack_start (Gtk.Label (""), False, True, 16)
        center.pack_start (spinner, False, True, 5)
        center.pack_start (Gtk.Label (""), False, True, 3)

        self.pack_start (center, False, False, 6)
        self.pack_start (bottom_spacer, False, False, 6)

    def update_start_button_status(self):
        hours = self.hours.get_value()
        minutes = self.minutes.get_value()
        seconds = self.seconds.get_value()
        if hours == 0 and minutes == 0 and seconds == 0:
            self.startButton.set_sensitive(False)
        else:
            self.startButton.set_sensitive(True)

    def _on_start_clicked(self, data):
        if self.timer.state == 0:
            self.timer.start()
