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

from gi.repository import Gtk, GObject, Gio, Gdk, Gst, Notify, cairo
from gi.repository.GdkPixbuf import Pixbuf

from widgets import NewWorldClockDialog, DigitalClock, NewAlarmDialog, AlarmWidget, WorldEmpty, AlarmsEmpty
from storage import worldclockstorage

from datetime import datetime, timedelta
from pytz import timezone
from timer import TimerWelcomeScreen, TimerScreen, Spinner
from alarm import AlarmItem, ICSHandler
import pytz, time, os


STOPWATCH_LABEL_MARKUP = "<span font_desc=\"64.0\">%02i:%02i</span>"
STOPWATCH_BUTTON_MARKUP = "<span font_desc=\"24.0\">%s</span>"

TIMER_LABEL_MARKUP = "<span font_desc=\"64.0\">%02i:%02i:%02i</span>"
TIMER = "<span font_desc=\"64.0\">%02i</span>"
TIMER_BUTTON_MARKUP = "<span font_desc=\"24.0\">%s</span>"

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

    def __init__ (self, label, hasNew = False, hasSelectionMode = False):
        Gtk.EventBox.__init__ (self)
        self.button = ToggleButton (label)
        self.hasNew = hasNew
        self.hasSelectionMode = hasSelectionMode
        self.get_style_context ().add_class ('grey-bg')

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
        Clock.__init__ (self, _("World"), True, True)
        self.addButton = None

        self.liststore = liststore = Gtk.ListStore(Pixbuf, str, GObject.TYPE_PYOBJECT)
        self.iconview = iconview = Gtk.IconView.new()

        self.empty_view = WorldEmpty ()

        iconview.set_model(liststore)
        iconview.set_spacing(3)
        iconview.set_pixbuf_column(0)
        iconview.get_style_context ().add_class ('grey-bg')

        renderer_text = Gtk.CellRendererText()
        renderer_text.set_alignment (0.5, 0.5)
        iconview.pack_start(renderer_text, True)
        iconview.add_attribute(renderer_text, "markup", 1)

        self.scrolledwindow = scrolledwindow = Gtk.ScrolledWindow()
        scrolledwindow.add(iconview)

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
        if len(self.clocks) == 0:
            self.load_empty_clocks_view ()
        else:
            for clock in self.clocks:
                d = DigitalClock (clock)
                view_iter = self.liststore.append([d.drawing.pixbuf, "<b>"+d.location.get_city_name()+"</b>", d])
                d.set_iter(self.liststore, view_iter)
            self.load_clocks_view ()

    def add_clock(self, location):
        location_id = location.id + "---" + location.location.get_code ()
        if not location_id in worldclockstorage.locations_dump:
            d = DigitalClock(location)
            self.clocks.append(location)
            view_iter = self.liststore.append([d.drawing.pixbuf, "<b>"+d.location.get_city_name()+"</b>", d])
            d.set_iter(self.liststore, view_iter)
            self.show_all()
        worldclockstorage.save_clocks (self.clocks)
        if len(self.clocks) > 0:
            self.load_clocks_view ()

    def delete_clock (self, d):
        self.clocks.remove (d.location)
        self.liststore.remove (d.view_iter)
        self.iconview.unselect_all ()
        if len(self.clocks) == 0:
            self.load_empty_clocks_view ()

    def open_new_dialog(self):
        parent = self.get_parent().get_parent().get_parent()
        window = NewWorldClockDialog(parent)
        #window.get_children()[0].pack_start(widget, False, False, 0)
        window.connect("add-clock", lambda w, l: self.add_clock(l))
        window.show_all()

    def close_new_dialog(self):
        self.notebook.set_current_page(0)
        self.addButton.set_sensitive(False)
        self.emit('show-requested')

    def load_clocks_view (self):
        if self.empty_view in self.get_children ():
            self.remove (self.empty_view)
        self.add (self.scrolledwindow)
        self.show_all ()

    def load_empty_clocks_view (self):
        if self.scrolledwindow in self.get_children ():
            self.remove (self.scrolledwindow)
        self.add (self.empty_view)
        self.show_all ()

class Alarm (Clock):
    def __init__ (self):
        Clock.__init__ (self, _("Alarm"), True, True)

        self.liststore = liststore = Gtk.ListStore(Pixbuf, str, GObject.TYPE_PYOBJECT)
        self.iconview = iconview = Gtk.IconView.new()

        self.empty_view = AlarmsEmpty()

        iconview.set_model(liststore)
        iconview.set_spacing(3)
        iconview.set_pixbuf_column(0)
        iconview.get_style_context ().add_class ('grey-bg')

        renderer_text = Gtk.CellRendererText()
        renderer_text.set_alignment (0.5, 0.5)
        iconview.pack_start(renderer_text, True)
        iconview.add_attribute(renderer_text, "markup", 1)

        self.scrolledwindow = Gtk.ScrolledWindow()
        self.scrolledwindow.add(iconview)

        self.alarms = []
        self.load_alarms()
        self.show_all()

    def get_system_clock_format(self):
        settings = Gio.Settings.new('org.gnome.desktop.interface')
        systemClockFormat = settings.get_string('clock-format')
        return systemClockFormat

    def load_alarms(self):
        handler = ICSHandler()
        vevents = handler.load_vevents()
        if vevents:
            for vevent in vevents:
                alarm = AlarmItem()
                alarm.new_from_vevent(vevent)
                scf = self.get_system_clock_format()
                if scf == "12h":
                    d = AlarmWidget(alarm.get_time_12h_as_string())
                else:
                    d = AlarmWidget(alarm.get_time_24h_as_string())
                view_iter = self.liststore.append([d.drawing.pixbuf, "<b>" + alarm.get_alarm_name() + "</b>", d])
                d.set_iter(self.liststore, view_iter)
                self.load_alarms_view()
        else:
            self.load_empty_alarms_view ()

    def load_alarms_view(self):
        if self.empty_view in self.get_children():
            self.remove(self.empty_view)
        self.add(self.scrolledwindow)
        self.show_all()

    def load_empty_alarms_view(self):
        if self.scrolledwindow in self.get_children():
            self.remove(self.scrolledwindow)
        self.add(self.empty_view)
        self.show_all()

    def add_alarm(self, alarm):
        handler = ICSHandler()
        handler.add_vevent(alarm.get_vevent())
        scf = self.get_system_clock_format()
        if scf == "12h":
            d = AlarmWidget(alarm.get_time_12h_as_string())
        else:
            d = AlarmWidget(alarm.get_time_24h_as_string())
        view_iter = self.liststore.append([d.drawing.pixbuf, "<b>" + alarm.get_alarm_name() + "</b>", d])
        d.set_iter(self.liststore, view_iter)
        self.show_all()
        vevents = handler.load_vevents()
        if vevents:
            self.load_alarms_view()

    def open_new_dialog(self):
        parent = self.get_parent ().get_parent ().get_parent ()
        window = NewAlarmDialog (parent)
        window.connect("add-alarm", lambda w, l: self.add_alarm(l))
        window.show_all ()

class Stopwatch (Clock):

    class State:
        RESET = 0
        RUNNING = 1
        STOPPED = 2

    def __init__ (self):
        Clock.__init__ (self, _("Stopwatch"))
        vbox = Gtk.Box (orientation = Gtk.Orientation.VERTICAL)
        self.add (vbox)

        top_spacer = Gtk.Box()
        center = Gtk.Box (orientation=Gtk.Orientation.VERTICAL)
        bottom_spacer = Gtk.Box (orientation=Gtk.Orientation.VERTICAL)

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
        self.rightButton.set_sensitive(False)
        self.leftButton.get_style_context ().add_class ("clocks-go")
        #self.rightButton.get_style_context ().add_class ("clocks-lap")

        hbox.pack_start (Gtk.Box(), True, False, 0)
        hbox.pack_start (self.leftButton, False, False, 0)
        hbox.pack_start (Gtk.Box(), False, False, 24)
        hbox.pack_start (self.rightButton, False, False, 0)
        hbox.pack_start (Gtk.Box(), True, False, 0)

        self.leftLabel.set_markup(STOPWATCH_BUTTON_MARKUP % (_("Start")))
        self.leftLabel.set_padding (6, 0)
        self.rightLabel.set_markup (STOPWATCH_BUTTON_MARKUP % (_("Reset")))
        self.rightLabel.set_padding (6, 0)

        center.pack_start (self.stopwatchLabel, False, False, 0)
        space = Gtk.EventBox()
        center.pack_start (Gtk.Box (), True, True, 41)
        center.pack_start (hbox, False, False, 0)

        self.state = Stopwatch.State.RESET
        self.g_id = 0
        self.start_time = 0
        self.time_diff = 0

        vbox.pack_start (Gtk.Box (), True, True, 48)
        vbox.pack_start (center, False, False, 0)
        vbox.pack_start (Gtk.Box (), True, True, 1)
        vbox.pack_start (Gtk.Box (), True, True, 41)

        self.leftButton.connect("clicked", self._on_left_button_clicked)
        self.rightButton.connect("clicked", self._on_right_button_clicked)

    def _on_left_button_clicked (self, widget):
        if self.state == Stopwatch.State.RESET or self.state == Stopwatch.State.STOPPED:
            self.state = Stopwatch.State.RUNNING
            self.start()
            self.leftLabel.set_markup(STOPWATCH_BUTTON_MARKUP % (_("Stop")))

            self.leftButton.get_style_context ().add_class ("clocks-stop")
            self.rightButton.set_sensitive(True)
        elif self.state == Stopwatch.State.RUNNING:
            self.state = Stopwatch.State.STOPPED
            self.stop()
            self.leftLabel.set_markup(STOPWATCH_BUTTON_MARKUP % (_("Continue")))
            self.rightLabel.set_markup(STOPWATCH_BUTTON_MARKUP % (_("Reset")))
            self.leftButton.get_style_context ().remove_class ("clocks-stop")
            self.leftButton.get_style_context ().add_class ("clocks-go")

    def _on_right_button_clicked (self, widget):
        if self.state == Stopwatch.State.RUNNING:
            pass
        if self.state == Stopwatch.State.STOPPED:
            self.state = Stopwatch.State.RESET
            self.time_diff = 0
            self.leftLabel.set_markup(STOPWATCH_BUTTON_MARKUP % (_("Start")))
            self.leftButton.get_style_context ().add_class ("clocks-go")
            #self.rightButton.get_style_context ().add_class ("clocks-lap")
            self.stopwatchLabel.set_markup (STOPWATCH_LABEL_MARKUP%(0,0))
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
        (elapsed_minutes, elapsed_seconds) = divmod(timediff, 60)
        elapsed_milli_seconds = int ((elapsed_seconds*100)%100)
        self.stopwatchLabel.set_markup (STOPWATCH_LABEL_MARKUP%(elapsed_minutes,
            elapsed_seconds))
        return True

class Timer (Clock):

    class State:
        STOPPED = 0
        RUNNING = 1
        PAUSED = 2

    def __init__ (self):
        Clock.__init__ (self, _("Timer"))
        self.state = Timer.State.STOPPED
        self.g_id = 0

        self.alert = Alert()
        self.vbox = Gtk.Box (orientation = Gtk.Orientation.VERTICAL)
        box = Gtk.Box ()
        self.add (box)
        box.pack_start (Gtk.Box (), True, True, 0)
        box.pack_start (self.vbox, False, False, 0)
        box.pack_end (Gtk.Box (), True, True, 0)

        self.timerbox = Gtk.Box (orientation = Gtk.Orientation.VERTICAL)
        self.vbox.pack_start (Gtk.Box (), True, True, 0)
        self.vbox.pack_start (self.timerbox, False, False, 0)
        self.vbox.pack_start (Gtk.Box (), True, True, 0)
        self.vbox.pack_start (Gtk.Box (), True, True, 46)

        self.timer_welcome_screen = TimerWelcomeScreen(self)
        self.timer_screen = TimerScreen(self)
        self.show_timer_welcome_screen()

    def show_timer_welcome_screen(self):
        self.timerbox.pack_start(self.timer_welcome_screen, True, True, 0)
        self.timer_welcome_screen.update_start_button_status()

    def start_timer_screen(self):
        self.timerbox.remove(self.timer_welcome_screen)
        self.timerbox.pack_start(self.timer_screen, True, True, 0)
        self.timerbox.show_all()

    def end_timer_screen(self):
        self.timer_screen.leftLabel.set_markup(TIMER_BUTTON_MARKUP % (_("Pause")))
        self.timerbox.remove(self.timer_screen)
        self.show_timer_welcome_screen()
        self.timer_welcome_screen.hours.set_value(0)
        self.timer_welcome_screen.minutes.set_value(0)
        self.timer_welcome_screen.seconds.set_value(0)
        self.timer_welcome_screen.update_start_button_status()

    def start(self):
        if self.g_id == 0:
            hours = self.timer_welcome_screen.hours.get_value()
            minutes = self.timer_welcome_screen.minutes.get_value()
            seconds = self.timer_welcome_screen.seconds.get_value()
            self.timer_screen.timerLabel.set_markup (TIMER_LABEL_MARKUP%(hours, minutes, seconds))
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

        self.timer_screen.timerLabel.set_markup (TIMER_LABEL_MARKUP%(hours, minutes, seconds))
        if hours == 00 and minutes == 00 and seconds == 00:
            self.alert.do_alert("Ta Da !")
            self.state = Timer.State.STOPPED
            self.timerbox.remove(self.timer_screen)
            self.show_timer_welcome_screen()
            if self.g_id != 0:
                GObject.source_remove(self.g_id)
            self.g_id = 0
            return False
        else:
            return True

class Alert:
    def __init__(self):
        Gst.init('gst')

    def do_alert(self, msg):
        if Notify.init("GNOME Clocks"):
            Alert = Notify.Notification.new("Clocks", msg, 'test')
            Alert.show()
            playbin = Gst.ElementFactory.make('playbin', None)
            playbin.set_property('uri', 'file:///usr/share/sounds/gnome/default/alerts/glass.ogg')
            playbin.set_state(Gst.State.PLAYING)
        else:
            print "Error: Could not trigger Alert"

