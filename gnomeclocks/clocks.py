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
from gi.repository.GdkPixbuf import Pixbuf

from widgets import NewWorldClockDialog, AlarmDialog
from widgets import DigitalClock, AlarmWidget, SelectableIconView, EmptyPlaceholder
from widgets import TogglePixbufRenderer
from storage import worldclockstorage
from utils import SystemSettings, Alert

from timer import TimerWelcomeScreen, TimerScreen
from alarm import AlarmItem, ICSHandler

import time

STOPWATCH_LABEL_MARKUP = "<span font_desc=\"64.0\">%02i:%02i</span>"
STOPWATCH_BUTTON_MARKUP = "<span font_desc=\"18.0\">%s</span>"


class Clock(Gtk.EventBox):
    __gsignals__ = {'show-requested': (GObject.SignalFlags.RUN_LAST,
                    None, ()),
                    'show-clock': (GObject.SignalFlags.RUN_LAST,
                    None, (GObject.TYPE_PYOBJECT, )),
                    'selection-changed': (GObject.SignalFlags.RUN_LAST,
                    None, ())}

    def __init__(self, label, hasNew=False, hasSelectionMode=False):
        Gtk.EventBox.__init__(self)
        self.label = label
        self.hasNew = hasNew
        self.hasSelectionMode = hasSelectionMode
        self.get_style_context().add_class('view')
        self.get_style_context().add_class('content-view')

    def open_new_dialog(self):
        pass

    def get_selection(self):
        pass

    def unselect_all(self):
        pass

    def delete_selected(self):
        pass


class World(Clock):
    def __init__(self):
        Clock.__init__(self, _("World"), True, True)

        self.empty_view = EmptyPlaceholder(
                "document-open-recent-symbolic",
                 _("Select <b>New</b> to add a world clock"))
        self.add(self.empty_view)

        self.liststore = Gtk.ListStore(bool,
                                       Pixbuf,
                                       str,
                                       GObject.TYPE_PYOBJECT)

        self.iconview = SelectableIconView(self.liststore, 0, 1, 2)

        self.scrolledwindow = Gtk.ScrolledWindow()
        self.scrolledwindow.add(self.iconview)

        self.liststore.connect("row-inserted", self._on_item_inserted)
        self.liststore.connect("row-deleted", self._on_item_deleted)
        self.iconview.connect("item-activated", self._on_item_activated)
        self.iconview.connect("selection-changed", self._on_selection_changed)

        self.clocks = []
        self.load_clocks()
        self.show_all()

    def _on_item_inserted(self, model, path, treeiter):
        self.update_empty_view()

    def _on_item_deleted(self, model, path):
        self.update_empty_view()

    def _on_item_activated(self, iconview, path):
        d = self.liststore[path][3]
        self.emit("show-clock", d)

    def _on_selection_changed(self, iconview):
        self.emit("selection-changed")

    def set_selection_mode(self, active):
        self.iconview.set_selection_mode(active)

    @GObject.Property(type=bool, default=False)
    def can_select(self):
        return len(self.liststore) != 0

    def get_selection(self):
        return self.iconview.get_selection()

    def delete_selected(self):
        selection = self.get_selection()
        items = []
        for treepath in selection:
            items.append(self.liststore[treepath][3])
        self.delete_clocks(items)

    def load_clocks(self):
        self.clocks = worldclockstorage.load_clocks()
        for clock in self.clocks:
            self.add_clock_widget(clock)

    def add_clock(self, location):
        location_id = location.id + "---" + location.location.get_code()
        if not location_id in worldclockstorage.locations_dump:
            self.clocks.append(location)
            self.add_clock_widget(location)
            self.show_all()
        worldclockstorage.save_clocks(self.clocks)

    def add_clock_widget(self, location):
        d = DigitalClock(location)
        name = d.location.get_city_name()
        view_iter = self.liststore.append([False,
                                           d.get_pixbuf(),
                                           "<b>" + name + "</b>",
                                           d])
        path = self.liststore.get_path(view_iter)
        d.set_path(self.liststore, path)
        self.notify("can-select")

    def delete_clocks(self, clocks):
        for d in clocks:
            d.stop_update()
            self.clocks.remove(d._location)
        worldclockstorage.save_clocks(self.clocks)
        self.iconview.unselect_all()
        self.liststore.clear()
        self.load_clocks()
        self.notify("can-select")

    def update_empty_view(self):
        if len(self.liststore) == 0:
            if self.scrolledwindow in self.get_children():
                self.remove(self.scrolledwindow)
                self.add(self.empty_view)
                self.show_all()
        else:
            if self.empty_view in self.get_children():
                self.remove(self.empty_view)
                self.add(self.scrolledwindow)
                self.show_all()

    def open_new_dialog(self):
        window = NewWorldClockDialog(self.get_toplevel())
        window.connect("response", self.on_dialog_response)
        window.show_all()

    def on_dialog_response(self, dialog, response):
        if response == 1:
            l = dialog.get_location()
            self.add_clock(l)
        dialog.destroy()


class Alarm(Clock):
    def __init__(self):
        Clock.__init__(self, _("Alarm"), True, True)

        self.empty_view = EmptyPlaceholder(
                "alarm-symbolic",
                _("Select <b>New</b> to add an alarm"))
        self.add(self.empty_view)

        self.liststore = Gtk.ListStore(bool,
                                       Pixbuf,
                                       str,
                                       GObject.TYPE_PYOBJECT,
                                       GObject.TYPE_PYOBJECT,
                                       GObject.TYPE_PYOBJECT)

        self.iconview = SelectableIconView(self.liststore, 0, 1, 2)

        self.scrolledwindow = Gtk.ScrolledWindow()
        self.scrolledwindow.add(self.iconview)

        self.liststore.connect("row-inserted", self._on_item_inserted)
        self.liststore.connect("row-deleted", self._on_item_deleted)
        self.iconview.connect("item-activated", self._on_item_activated)
        self.iconview.connect("selection-changed", self._on_selection_changed)

        self.load_alarms()
        self.show_all()

        self.timeout_id = GObject.timeout_add(1000, self._check_alarms)

    def _check_alarms(self):
        for i in self.liststore:
            alarm = self.liststore.get_value(i.iter, 5)
            if alarm.check_expired():
                print alarm
                alert = self.liststore.get_value(i.iter, 4)
                alert.show()
        return True

    def _on_notification_activated(self, notif, action, data):
        win = self.get_toplevel()
        win.show_clock(self)

    def _on_item_inserted(self, model, path, treeiter):
        self.update_empty_view()

    def _on_item_deleted(self, model, path):
        self.update_empty_view()

    def _on_item_activated(self, iconview, path):
        alarm = self.liststore[path][-1]
        self.open_edit_dialog(alarm.get_vevent())

    def _on_selection_changed(self, iconview):
        self.emit("selection-changed")

    def set_selection_mode(self, active):
        self.iconview.set_selection_mode(active)

    @GObject.Property(type=bool, default=False)
    def can_select(self):
        return len(self.liststore) != 0

    def get_selection(self):
        return self.iconview.get_selection()

    def delete_selected(self):
        selection = self.get_selection()
        items = []
        for treepath in selection:
            v = self.liststore[treepath][-1].get_vevent()
            items.append(v.uid.value)
        self.delete_alarms(items)

    def load_alarms(self):
        handler = ICSHandler()
        vevents = handler.load_vevents()
        for vevent in vevents:
            alarm = AlarmItem()
            alarm.new_from_vevent(vevent)
            self.add_alarm_widget(alarm)

    def update_empty_view(self):
        if len(self.liststore) == 0:
            if self.scrolledwindow in self.get_children():
                self.remove(self.scrolledwindow)
                self.add(self.empty_view)
                self.show_all()
        else:
            if self.empty_view in self.get_children():
                self.remove(self.empty_view)
                self.add(self.scrolledwindow)
                self.show_all()

    def add_alarm(self, alarm):
        handler = ICSHandler()
        handler.add_vevent(alarm.get_vevent())
        self.add_alarm_widget(alarm)
        self.show_all()
        vevents = handler.load_vevents()

    def add_alarm_widget(self, alarm):
        name = alarm.get_alarm_name()
        timestr = alarm.get_time_as_string()
        repeat = alarm.get_alarm_repeat_string()
        widget = AlarmWidget(timestr, repeat)
        alert = Alert("alarm-clock-elapsed", name,
                      self._on_notification_activated)
        view_iter = self.liststore.append([False,
                                           widget.get_pixbuf(),
                                           "<b>" + name + "</b>",
                                           widget,
                                           alert,
                                           alarm])
        self.notify("can-select")

    def edit_alarm(self, old_vevent, alarm):
        handler = ICSHandler()
        handler.update_vevent(old_vevent, alarm.get_vevent())
        self.iconview.unselect_all()
        self.liststore.clear()
        self.load_alarms()

    def delete_alarms(self, alarms):
        handler = ICSHandler()
        handler.remove_vevents(alarms)
        self.iconview.unselect_all()
        self.liststore.clear()
        self.load_alarms()
        self.notify("can-select")

    def open_new_dialog(self):
        window = AlarmDialog(self, self.get_toplevel())
        window.connect("response", self.on_dialog_response, None)
        window.show_all()

    def open_edit_dialog(self, vevent):
        window = AlarmDialog(self, self.get_toplevel(), vevent)
        window.connect("response", self.on_dialog_response, vevent)
        window.show_all()

    def on_dialog_response(self, dialog, response, old_vevent):
        if response == 1:
            alarm = dialog.get_alarm_item()
            if old_vevent:
                self.edit_alarm(old_vevent, alarm)
            else:
                self.add_alarm(alarm)
        dialog.destroy()


class Stopwatch(Clock):

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
        self.stopwatchLabel.set_markup(STOPWATCH_LABEL_MARKUP % (0, 0))

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

        self.leftLabel.set_markup(STOPWATCH_BUTTON_MARKUP % (_("Start")))
        self.leftLabel.set_padding(6, 0)
        self.rightLabel.set_markup(STOPWATCH_BUTTON_MARKUP % (_("Reset")))
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
            self.leftLabel.set_markup(STOPWATCH_BUTTON_MARKUP % (_("Stop")))
            self.leftButton.get_style_context().add_class("clocks-stop")
            self.rightButton.set_sensitive(True)
        elif self.state == Stopwatch.State.RUNNING:
            self.state = Stopwatch.State.STOPPED
            self.stop()
            self.leftLabel.set_markup(STOPWATCH_BUTTON_MARKUP %
                (_("Continue")))
            self.rightLabel.set_markup(STOPWATCH_BUTTON_MARKUP %
                (_("Reset")))
            self.leftButton.get_style_context().remove_class("clocks-stop")
            self.leftButton.get_style_context().add_class("clocks-go")

    def _on_right_button_clicked(self, widget):
        if self.state == Stopwatch.State.RUNNING:
            pass
        if self.state == Stopwatch.State.STOPPED:
            self.state = Stopwatch.State.RESET
            self.time_diff = 0
            self.leftLabel.set_markup(STOPWATCH_BUTTON_MARKUP % (_("Start")))
            self.leftButton.get_style_context().add_class("clocks-go")
            #self.rightButton.get_style_context().add_class("clocks-lap")
            self.stopwatchLabel.set_markup(STOPWATCH_LABEL_MARKUP % (0, 0))
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
        self.stopwatchLabel.set_markup(STOPWATCH_LABEL_MARKUP %
            (elapsed_minutes, elapsed_seconds))
        return True


class Timer(Clock):

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
        if self.g_id == 0:
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
