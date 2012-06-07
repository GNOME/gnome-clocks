"""
 Copyright (c) 2011-2012 Collabora, Ltd.

 Gnome Clocks is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by the
 Free Software Foundation; either version 2 of the License, or (at your
 option) any later version.

 Gnome Clocks is distributed in the hope that it will be useful, but
 WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
 or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 for more details.
 
 You should have received a copy of the GNU General Public License along
 with Gnome Documents; if not, write to the Free Software Foundation,
 Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 
 Author: Eslam Mostafa <cseslam@gmail.com>
"""


from gi.repository import Gtk, Gio

TIMER = "<span font_desc=\"64.0\">%02i</span>"
TIMER_LABEL_MARKUP = "<span font_desc=\"64.0\">%02i:%02i</span>"
TIMER = "<span font_desc=\"64.0\">%02i</span>"
TIMER_BUTTON_MARKUP = "<span font_desc=\"24.0\">%s</span>"

class Spinner(Gtk.Box):
	def __init__(self, value_type, timer_welcome_screen):
		super(Spinner, self).__init__()
		self.vType = value_type
		self.timer_welcome_screen = timer_welcome_screen
		self.set_orientation(Gtk.Orientation.VERTICAL)
		iconUp = Gio.ThemedIcon.new_with_default_fallbacks ("go-up-symbolic")
		iconDown = Gio.ThemedIcon.new_with_default_fallbacks ("go-down-symbolic")
		imageUp = Gtk.Image.new_from_gicon(iconUp, Gtk.IconSize.BUTTON)
		imageDown = Gtk.Image.new_from_gicon(iconDown, Gtk.IconSize.BUTTON)
		#Up Button
		self.up = Gtk.Button()
		self.up.set_image(imageUp)
		self.up.set_relief(Gtk.ReliefStyle.NONE)
		#Value
		self.value = Gtk.Label('')
		self.value.set_markup(TIMER%(0))
		#Down Button
		self.down = Gtk.Button()
		self.down.set_image(imageDown)
		self.down.set_relief(Gtk.ReliefStyle.NONE)
		#
		self.pack_start(self.up, False, False, 5)
		self.pack_start(self.value, False, False, 5)
		self.pack_start(self.down, False, False, 5)
		#Signals
		self.up.connect('clicked', self._increase)
		self.down.connect('clicked', self._decrease)
		
	def get_value(self):
		return int(self.value.get_text())
		
	def set_value(self, newValue):
		self.value.set_markup(TIMER%(newValue))
		
	def _increase(self, widget):
		value = self.get_value()
		if self.vType == 'hours':
			if value == 23:
				value = 0
			else:
				value += 1
			self.set_value(value)
		elif self.vType == 'minutes':
			if value == 59:
				value = 0
			else:
				value += 1
			self.set_value(value)
		self.timer_welcome_screen.update_start_button_status()
			
	def _decrease(self, widget):
		value = self.get_value()
		if self.vType == 'hours':
			if value == 0:
				value = 23
			else:
				value -= 1
			self.set_value(value)
		elif self.vType == 'minutes':
			if value == 0:
				value = 59
			else:
				value -= 1
			self.set_value(value)	
		self.timer_welcome_screen.update_start_button_status()
			
class TimerScreen (Gtk.Box):
	def __init__(self, timer):
		super(TimerScreen, self).__init__()
		self.set_orientation(Gtk.Orientation.VERTICAL)
		self.timer = timer
		top_spacer = Gtk.Label("")
		
		contents = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
		self.timerLabel = Gtk.Label ()
		self.timerLabel.set_alignment (0.5, 0.5)
		self.timerLabel.set_markup (TIMER_LABEL_MARKUP%(0,0))
		contents.pack_start (self.timerLabel, False, False, 0)

		hbox = Gtk.Box()		
		self.leftButton = Gtk.Button ()
		self.leftButton.set_size_request(200, -1)
		self.leftLabel = Gtk.Label ()
		self.leftButton.add (self.leftLabel)
		self.rightButton = Gtk.Button ()
		self.rightButton.set_size_request(200, -1)
		self.rightLabel = Gtk.Label ()
		self.rightButton.add (self.rightLabel)

		self.leftButton.get_style_context ().add_class ("clocks-stop")
		self.rightButton.get_style_context ().add_class ("clocks-lap")

		hbox.pack_start (self.leftButton, True, True, 0)
		hbox.pack_start (Gtk.Box(), True, True, 24)
		hbox.pack_start (self.rightButton, True, True, 0)

		box = Gtk.Box ()
		box.pack_start (Gtk.Box (), True, True, 0)
		box.pack_start (hbox, True, True, 0)
		box.pack_start (Gtk.Box (), True, True, 0)

		contents.pack_start (box, False, False, 32)
		contents.pack_start (Gtk.Box(), True, True, 0)
		contents.pack_start (Gtk.Box(), True, True, 0)

		self.leftLabel.set_markup (TIMER_BUTTON_MARKUP%("Cancel"))
		self.leftLabel.set_padding (6, 0)
		self.rightLabel.set_markup (TIMER_BUTTON_MARKUP%("Pause"))
		self.rightLabel.set_padding (6, 0)
		
		bottom_spacer = Gtk.Label("")
		
		self.leftButton.connect('clicked', self._on_left_button_clicked)
		self.rightButton.connect('clicked', self._on_right_button_clicked)
		
		self.pack_start(top_spacer, True, True, 0)
		self.pack_start(contents, False, False, 0)		
		self.pack_start(bottom_spacer, True, True, 0)
	
		
	def _on_left_button_clicked(self, data):
		self.timer.cancel()
		
	def _on_right_button_clicked(self, widget):
		if self.timer.state == 1: #Pause
			self.timer.state = 2
			self.timer.pause()
			self.rightButton.get_style_context ().remove_class ("clocks-lap")
			self.rightButton.get_style_context ().add_class ("clocks-start")
			self.rightLabel.set_markup(TIMER_BUTTON_MARKUP%("Continue"))
			
		elif self.timer.state == 2: #Continue
			self.timer.state = 1
			self.timer.cont()
			self.rightButton.get_style_context ().remove_class ("clocks-start")
			self.rightButton.get_style_context ().add_class ("clocks-lap")
			self.rightLabel.set_markup(TIMER_BUTTON_MARKUP%("Pause"))	
			
class TimerWelcomeScreen (Gtk.Box):
	def __init__ (self, timer):
		super(TimerWelcomeScreen, self).__init__ ()
		self.timer = timer
		self.set_orientation(Gtk.Orientation.VERTICAL)
		
		top_spacer = Gtk.Label('')
		spinner = Gtk.Box () #Containes 3 columns to set the time
		
		self.hours = Spinner('hours', self)
		self.minutes = Spinner('minutes', self)
		colon = Gtk.Label('')
		colon.set_markup('<span font_desc=\"64.0\">:</span>')
		
		spinner.pack_start(self.hours, False, True, 20)
		spinner.pack_start(colon, False, True, 20)
		spinner.pack_start(self.minutes, False, True, 20)
			
		#Start Button
		self.startButton = Gtk.Button()
		self.startButton.set_sensitive(False)
		self.startButton.set_size_request(200, -1)
		self.startButton.get_style_context ().add_class ("clocks-start")
		self.startLabel = Gtk.Label()
		self.startLabel.set_markup (TIMER_BUTTON_MARKUP%("Start"))
		self.startLabel.set_padding (6, 0)
		self.startButton.add(self.startLabel)
		self.startButton.connect('clicked', self._on_start_clicked)
		#
		bottom_spacer = Gtk.Label("")
		#
		self.pack_start(top_spacer, True, True, 0)
		self.pack_start(spinner, False, True, 5)
		self.pack_start(self.startButton, False, True, 5)
		self.pack_start(bottom_spacer, True, True, 0)
		
	def update_start_button_status(self):
		hours = self.hours.get_value()
		minutes = self.minutes.get_value()
		if hours == 0 and minutes == 0:
			self.startButton.set_sensitive(False)
		else:
			self.startButton.set_sensitive(True)
		

	def _on_start_clicked(self, data):
		if self.timer.state == 0:
			self.timer.start_timer_screen()
			self.timer.start()
