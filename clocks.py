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
 
 Author: Seif Lotfy <seif.lotfy@collabora.co.uk>
"""

from gi.repository import Gtk, GObject, Gio, Gdk
from gi.repository.GdkPixbuf import Pixbuf

from widgets import NewWorldClockWidget, DigitalClock
from storage import worldclockstorage

from datetime import datetime, timedelta
from pytz import timezone
from timer import TimerWelcomeScreen, TimerScreen, Spinner
import pytz, time, os


STOPWATCH_LABEL_MARKUP = "<span font_desc=\"64.0\">%02i:%04.1f</span>"
STOPWATCH_BUTTON_MARKUP = "<span font_desc=\"24.0\">%s</span>"

TIMER_LABEL_MARKUP = "<span font_desc=\"64.0\">%02i:%02i</span>"
TIMER = "<span font_desc=\"64.0\">%02i</span>"
TIMER_BUTTON_MARKUP = "<span font_desc=\"24.0\">%s</span>"

GFILE = Gio.File.new_for_uri ('widgets.css')
CSS_PROVIDER = Gtk.CssProvider()
#CSS_PROVIDER.load_from_file(GFILE)

class ToggleButton(Gtk.ToggleButton):
    def __init__(self, text):
        Gtk.ToggleButton.__init__(self)
        self.text = text
        self.label = Gtk.Label()
        self.label.set_markup("%s" %text)
        self.add(self.label)
        self.connect("toggled", self._on_toggled)
        self.set_size_request(100, 34)
        
    def _on_toggled(self, label):
        if self.get_active():
            self.label.set_markup("<b>%s</b>"%self.text)
        else:
            self.label.set_markup("%s" %self.text)

class Clock (Gtk.EventBox):
    __gsignals__ = {'show-requested': (GObject.SignalFlags.RUN_LAST,
                    None, ()),
                    'show-clock': (GObject.SignalFlags.RUN_LAST,
                    None, (GObject.TYPE_PYOBJECT,))}

    def __init__ (self, label, hasNew = False):
        Gtk.EventBox.__init__ (self)
        self.button = ToggleButton (label)
        self.hasNew = hasNew
    
    def open_new_dialog(self):
        pass
        
    def close_new_dialog(self):
        pass
    
    def add_new_clock(self):
        pass
        
    def unselect_all (self):
        pass

class World (Clock):
    def __init__ (self):
        Clock.__init__ (self, "World", True)
        self.addButton = None
        #self.grid = Gtk.Grid()
        #self.grid.set_border_width(15)
        #self.grid.set_column_spacing (15)
        #self.add(self.grid)
        
        self.liststore = liststore = Gtk.ListStore(Pixbuf, str, GObject.TYPE_PYOBJECT)
        self.iconview = iconview = Gtk.IconView.new()
        
        iconview.set_model(liststore)
        
        iconview.set_spacing(3)
        iconview.set_pixbuf_column(0)
        iconview.set_markup_column(1)
        iconview.set_item_width(32)

        scrolledwindow = Gtk.ScrolledWindow()
        scrolledwindow.add(iconview)
        self.add(scrolledwindow)

        iconview.connect ("selection-changed", self._on_selection_changed)

        self.clocks = []
        self.load_clocks()
        self.show_all()

    def unselect_all (self):
        self.iconview.unselect_all ()

    def _on_selection_changed (self, iconview):
        items = iconview.get_selected_items ()
        if items:
            path = iconview.get_selected_items ()[0]
            d = self.liststore [path][2]
            self.emit ("show-clock", d)

    def set_addButton(self, btn):
        self.addButton = btn

    def load_clocks(self):
        self.clocks = worldclockstorage.load_clocks ()
        for clock in self.clocks:
            self.add_clock (clock)

    def add_clock(self, location):
        d = DigitalClock(location)
        self.clocks.append(d)
        #self.grid.add(d)
        view_iter = self.liststore.append([d.drawing.pixbuf, "<b>"+d.location.get_city_name()+"</b>", d])
        d.set_iter(self.liststore, view_iter)
        self.show_all()
        worldclockstorage.save_clocks (location)

    def open_new_dialog(self):
        #self.newWorldClockWidget.
        #self.newWorldClockWidget.searchEntry.grab_focus()
        window = Gtk.Dialog("Add New Clock")
        parent = self.get_parent().get_parent().get_parent()
        window.set_transient_for(parent)
        window.set_modal(True)
        widget = NewWorldClockWidget()
        #window.add(widget)
        window.get_children()[0].pack_start(widget, False, False, 0)
        widget.connect("add-clock", lambda w, l: self.add_clock(l))
        widget.connect_after("add-clock", lambda w, e: window.destroy())
        window.show_all()

    def close_new_dialog(self):
        self.newWorldClockWidget.reset()
        self.notebook.set_current_page(0)
        self.addButton.set_sensitive(False)
        self.emit('show-requested')


class Alarm (Clock):
    def __init__ (self):
        Clock.__init__ (self, "Alarm", True)
        self.button.set_sensitive (False)

class Stopwatch (Clock):

    # State
    # Reset: 0
    # Running: 1
    # Stopped: 2

    def __init__ (self):
        Clock.__init__ (self, "Stopwatch")
        vbox = Gtk.Box (orientation = Gtk.Orientation.VERTICAL)
        box = Gtk.Box ()
        self.add (box)
        box.pack_start (Gtk.Box(), True, True, 0)
        box.pack_start (vbox, False, False, 0)
        box.pack_end (Gtk.Box(), True, True, 0)

        self.stopwatchLabel = Gtk.Label ()
        self.stopwatchLabel.set_alignment (0.5, 0.5)
        self.stopwatchLabel.set_markup (STOPWATCH_LABEL_MARKUP%(0,0))

        hbox = Gtk.Box()
        self.leftButton = Gtk.Button ()
        self.leftButton.set_size_request(200, -1)
        self.leftLabel = Gtk.Label ()
        self.leftButton.add (self.leftLabel)
        self.rightButton = Gtk.Button ()
        self.rightButton.set_size_request(200, -1)
        self.rightLabel = Gtk.Label ()
        self.rightButton.add (self.rightLabel)

        self.leftButton.get_style_context ().add_class ("clocks-start")
        self.rightButton.get_style_context ().add_class ("clocks-lap")

        hbox.pack_start (self.leftButton, True, True, 0)
        hbox.pack_start (Gtk.Box(), True, True, 24)
        hbox.pack_start (self.rightButton, True, True, 0)

        vbox.pack_start (Gtk.Label(""), True, True, 0)
        vbox.pack_start (self.stopwatchLabel, False, False, 0)
        vbox.pack_start (hbox, False, False, 32)
        vbox.pack_start (Gtk.Box(), True, True, 0)
        vbox.pack_start (Gtk.Box(), True, True, 0)

        self.leftLabel.set_markup (STOPWATCH_BUTTON_MARKUP%("Start"))
        self.leftLabel.set_padding (6, 0)
        self.rightLabel.set_markup (STOPWATCH_BUTTON_MARKUP%("Lap"))
        self.rightLabel.set_padding (6, 0)
        
        self.state = 0
        self.g_id = 0
        self.start_time = 0
        self.time_diff = 0
        
        self.leftButton.connect("clicked", self._on_left_button_clicked)
        self.rightButton.connect("clicked", self._on_right_button_clicked)
    
    def _on_left_button_clicked (self, widget):
        if self.state == 0 or self.state == 2:
            self.state = 1
            self.start()
            self.leftLabel.set_markup (STOPWATCH_BUTTON_MARKUP%("Stop"))
            self.rightLabel.set_markup (STOPWATCH_BUTTON_MARKUP%("Lap"))
            self.leftButton.get_style_context ().add_class ("clocks-stop")
        elif self.state == 1:
            self.state = 2
            self.stop()
            self.leftLabel.set_markup (STOPWATCH_BUTTON_MARKUP%("Continue"))
            self.rightLabel.set_markup (STOPWATCH_BUTTON_MARKUP%("Reset"))
            self.leftButton.get_style_context ().remove_class ("clocks-stop")
            self.leftButton.get_style_context ().add_class ("clocks-start")

    def _on_right_button_clicked (self, widget):
        if self.state == 1:
            pass
        if self.state == 2:
            self.state = 0
            self.time_diff = 0
            self.leftLabel.set_markup (STOPWATCH_BUTTON_MARKUP%("Start"))
            self.leftButton.get_style_context ().add_class ("clocks-start")
            self.rightButton.get_style_context ().add_class ("clocks-lap")
            self.stopwatchLabel.set_markup (STOPWATCH_LABEL_MARKUP%(0,0))

    def start(self):
        if self.g_id == 0:
            self.start_time = time.time()
            self.g_id = GObject.timeout_add(10, self.count)

    def stop(self):
        GObject.source_remove(self.g_id)
        self.g_id = 0
        self.time_diff = self.time_diff + (time.time() - self.start_time)
        print self.time_diff

    def reset(self):
        self.time_diff = 0
        GObject.source_remove(self.g_id)
        self.g_id = 0

    def count(self):
        timediff = time.time() - self.start_time + self.time_diff
        (elapsed_minutes, elapsed_seconds) = divmod(timediff, 60.0)
        
        self.stopwatchLabel.set_markup (STOPWATCH_LABEL_MARKUP%(elapsed_minutes,
            elapsed_seconds))
        
        return True
        


class Timer (Clock):
	
	#State
	#Zero: 0
	#Running: 1
	#Paused: 2
	
	def __init__ (self):
		Clock.__init__ (self, "Timer")
		self.state = 0
		self.g_id = 0
		#
		self.vbox = Gtk.Box (orientation = Gtk.Orientation.VERTICAL)
		box = Gtk.Box ()
		self.add (box)
		box.pack_start (Gtk.Box(), True, True, 0)
		box.pack_start (self.vbox, False, False, 0)
		box.pack_end (Gtk.Box(), True, True, 0)
		self.timer_welcome_screen = TimerWelcomeScreen(self)
		self.timer_screen = TimerScreen(self)
		self.show_timer_welcome_screen()
		
	def show_timer_welcome_screen(self):
		self.vbox.pack_start(self.timer_welcome_screen, True, True, 0)
		
	def start_timer_screen(self):
		self.vbox.remove(self.timer_welcome_screen)
		self.vbox.pack_start(self.timer_screen, True, True, 0)
		self.vbox.show_all()
	
	def end_timer_screen(self):
		self.timer_screen.rightButton.get_style_context ().add_class ("clocks-lap")
		self.timer_screen.rightLabel.set_markup (TIMER_BUTTON_MARKUP%("Pause"))
		self.vbox.remove(self.timer_screen)
		self.show_timer_welcome_screen()
			
	def start(self):
		if self.g_id == 0: 
			hours = self.timer_welcome_screen.hours.get_value()
			minutes = self.timer_welcome_screen.minutes.get_value()
			self.time = (hours * 60 * 60) + (minutes * 60) 
			self.state = 1
			self.g_id = GObject.timeout_add(1000, self.count)
		
	def cancel(self):
		self.state = 0
		self.end_timer_screen()
		if self.g_id != 0:
			GObject.source_remove(self.g_id)
			self.g_id = 0
		
	def pause(self):
		GObject.source_remove(self.g_id)
		self.g_id = 0
		
	def cont(self):
		self.g_id = GObject.timeout_add(1000, self.count)
	
	def count(self):
		self.time -= 1
		minutes, sec = divmod(self.time, 60)
		hours, minutes = divmod(minutes, 60)

		self.timer_screen.timerLabel.set_markup (TIMER_LABEL_MARKUP%(hours, minutes))
		if hours == 00 and minutes == 00 and sec == 00:
			return False
		else:
			return True
