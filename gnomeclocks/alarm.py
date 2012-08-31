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

import os
import errno
import time
import json
from datetime import datetime, timedelta
from gi.repository import GLib, GObject, Gio, Gtk, GdkPixbuf
from gi.repository import GWeather
from clocks import Clock
from utils import Dirs, SystemSettings, LocalizedWeekdays, Alert
from widgets import DigitalClockDrawing, SelectableIconView, ContentView


class AlarmsStorage():
    def __init__(self):
        self.filename = os.path.join(Dirs.get_user_data_dir(), "alarms.json")

    def save(self, alarms):
        alarm_list = []
        for a in alarms:
            d = {
                "name": a.name,
                "hour": a.time.strftime("%H"),
                "minute": a.time.strftime("%M"),
                "repeat": a.repeat
            }
            alarm_list.append(d)
        f = open(self.filename, "wb")
        json.dump(alarm_list, f)
        f.close()

    def load(self):
        alarms = []
        try:
            f = open(self.filename, "rb")
            alarm_list = json.load(f)
            f.close()
            for a in alarm_list:
                alarm = AlarmItem(a['name'], int(a['hour']), int(a['minute']), a['repeat'])
                alarms.append(alarm)
        except IOError as e:
            if e.errno == errno.ENOENT:
                # File does not exist yet, that's ok
                pass

        return alarms


class AlarmItem:
    def __init__(self, name=None, hour=None, minute=None, repeat=None):
        self.update(name=name, hour=hour, minute=minute, repeat=repeat)

    def update(self, name=None, hour=None, minute=None, repeat=None):
        self.name = name
        self.hour = hour
        self.minute = minute
        self.repeat = repeat
        if not hour == None and not minute == None:
            t = datetime.strptime("%02i:%02i" % (hour, minute), "%H:%M")
            self.time = datetime.combine(datetime.today(), t.time())
            self.expired = datetime.now() > self.time
        else:
            self.time = None
            self.expired = True

    def get_time_as_string(self):
        if SystemSettings.get_clock_format() == "12h":
            return self.time.strftime("%I:%M %p")
        else:
            return self.time.strftime("%H:%M")

    def get_alarm_repeat_string(self):
        # lists only compare the same if corresponing elements are the same
        # we form self.repeat by random appending
        # sorted(list of days)
        sorted_repeat = sorted(self.repeat)
        if sorted_repeat == ['FR', 'MO', 'SA', 'SU', 'TH', 'TU', 'WE']:
            return _("Every day")
        elif sorted_repeat == ['FR', 'MO', 'TH', 'TU', 'WE']:
            return _("Weekdays")
        elif len(sorted_repeat) == 0:
            return ""
        else:
            days = []
            if 'MO' in self.repeat:
                days.append(LocalizedWeekdays.MO)
            if 'TU' in self.repeat:
                days.append(LocalizedWeekdays.TU)
            if 'WE' in self.repeat:
                days.append(LocalizedWeekdays.WE)
            if 'TH' in self.repeat:
                days.append(LocalizedWeekdays.TH)
            if 'FR' in self.repeat:
                days.append(LocalizedWeekdays.FR)
            if 'SA' in self.repeat:
                days.append(LocalizedWeekdays.SA)
            if 'SU' in self.repeat:
                days.append(LocalizedWeekdays.SU)
            return ", ".join(days)

    # FIXME: this is not a really good way, we assume each alarm
    # can ring only once while the program is running
    def check_expired(self):
        if self.expired:
            return False
        self.expired = datetime.now() > self.time
        return self.expired


class AlarmDialog(Gtk.Dialog):
    def __init__(self, parent, alarm=None):
        if alarm:
            Gtk.Dialog.__init__(self, _("Edit Alarm"), parent)
        else:
            Gtk.Dialog.__init__(self, _("New Alarm"), parent)
        self.set_border_width(6)
        self.parent = parent
        self.set_transient_for(parent)
        self.set_modal(True)
        self.day_buttons = []

        content_area = self.get_content_area()
        self.add_buttons(Gtk.STOCK_CANCEL, 0, Gtk.STOCK_SAVE, 1)

        self.cf = SystemSettings.get_clock_format()
        grid = Gtk.Grid()
        grid.set_row_spacing(9)
        grid.set_column_spacing(6)
        grid.set_border_width(6)
        content_area.pack_start(grid, True, True, 0)

        if alarm:
            if self.cf == "12h":
                h = int(alarm.time.strftime("%I"))
                p = alarm.time.strftime("%p")
            else:
                h = alarm.hour
                p = None
            m = alarm.minute
            name = alarm.name
            repeat = alarm.repeat
        else:
            t = time.localtime()
            h = t.tm_hour
            m = t.tm_min
            p = time.strftime("%p", t)
            name = _("New Alarm")
            repeat = []

        label = Gtk.Label(_("Time"))
        label.set_alignment(1.0, 0.5)
        grid.attach(label, 0, 0, 1, 1)

        self.hourselect = Gtk.SpinButton()
        self.hourselect.set_increments(1.0, 1.0)
        self.hourselect.set_wrap(True)
        grid.attach(self.hourselect, 1, 0, 1, 1)

        label = Gtk.Label(": ")
        label.set_alignment(0.5, 0.5)
        grid.attach(label, 2, 0, 1, 1)

        self.minuteselect = Gtk.SpinButton()
        self.minuteselect.set_increments(1.0, 1.0)
        self.minuteselect.set_wrap(True)
        self.minuteselect.connect('output', self._show_leading_zeros)
        self.minuteselect.set_range(0.0, 59.0)
        self.minuteselect.set_value(m)
        grid.attach(self.minuteselect, 3, 0, 1, 1)

        if self.cf == "12h":
            self.ampm = Gtk.ComboBoxText()
            self.ampm.append_text("AM")
            self.ampm.append_text("PM")
            if p == "PM":
                h = h - 12
                self.ampm.set_active(1)
            else:
                self.ampm.set_active(0)
            grid.attach(self.ampm, 4, 0, 1, 1)
            self.hourselect.set_range(1.0, 12.0)
            self.hourselect.set_value(h)
            gridcols = 5
        else:
            self.hourselect.set_range(0.0, 23.0)
            self.hourselect.set_value(h)
            gridcols = 4

        label = Gtk.Label(_("Name"))
        label.set_alignment(1.0, 0.5)
        grid.attach(label, 0, 1, 1, 1)

        self.entry = Gtk.Entry()
        self.entry.set_text(name)
        self.entry.set_editable(True)
        grid.attach(self.entry, 1, 1, gridcols - 1, 1)

        label = Gtk.Label(_("Repeat Every"))
        label.set_alignment(1.0, 0.5)
        grid.attach(label, 0, 2, 1, 1)

        # create a box and put repeat days in it
        box = Gtk.Box(True, 0)
        box.get_style_context().add_class("linked")
        for day in ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]:
            btn = Gtk.ToggleButton(label=_(day))
            btn.data = day[:2].upper()
            if btn.data in repeat:
                btn.set_active(True)
            box.pack_start(btn, True, True, 0)
            self.day_buttons.append(btn)
        grid.attach(box, 1, 2, gridcols - 1, 1)

    def _show_leading_zeros(self, spin_button):
        spin_button.set_text('{: 02d}'.format(spin_button.get_value_as_int()))
        return True

    def get_alarm_item(self):
        name = self.entry.get_text()
        h = self.hourselect.get_value_as_int()
        m = self.minuteselect.get_value_as_int()
        if self.cf == "12h":
            r = self.ampm.get_active()
            if r == 0 and h == 12:
                h = 0
            elif r == 1 and h != 12:
                h += 12
        repeat = []
        for btn in self.day_buttons:
            if btn.get_active():
                repeat.append(btn.data)
        alarm = AlarmItem(name, h, m, repeat)
        return alarm


class AlarmWidget():
    def __init__(self, view, alarm, alert):
        self.view = view
        self.alarm = alarm
        self.alert = alert
        timestr = alarm.get_time_as_string()
        repeat = alarm.get_alarm_repeat_string()
        self.drawing = DigitalClockDrawing()
        isDay = self.get_is_day(int(timestr[:2]))
        if isDay:
            img = os.path.join(Dirs.get_image_dir(), "cities", "day.png")
        else:
            img = os.path.join(Dirs.get_image_dir(), "cities", "night.png")
        self.drawing.render(timestr, img, isDay, repeat)
        self.standalone = None

    def get_is_day(self, hours):
        if hours > 7 and hours < 19:
            return True
        else:
            return False

    def get_pixbuf(self):
        return self.drawing.pixbuf

    def get_alert(self):
        return self.alert

    def get_standalone_widget(self):
        if not self.standalone:
            self.standalone = StandaloneAlarm(self.view, self.alarm, self.alert)
        return self.standalone


class Alarm(Clock):
    def __init__(self):
        Clock.__init__(self, _("Alarm"), True, True)

        self.liststore = Gtk.ListStore(bool,
                                       GdkPixbuf.Pixbuf,
                                       str,
                                       GObject.TYPE_PYOBJECT,
                                       GObject.TYPE_PYOBJECT)

        self.iconview = SelectableIconView(self.liststore, 0, 1, 2)

        contentview = ContentView(self.iconview,
                "alarm-symbolic",
                _("Select <b>New</b> to add an alarm"))
        self.add(contentview)

        self.iconview.connect("item-activated", self._on_item_activated)
        self.iconview.connect("selection-changed", self._on_selection_changed)

        self.storage = AlarmsStorage()

        self.load_alarms()
        self.show_all()

        self.timeout_id = GObject.timeout_add(1000, self._check_alarms)

    def _check_alarms(self):
        for i in self.liststore:
            alarm = self.liststore.get_value(i.iter, 4)
            if alarm.check_expired():
                widget = self.liststore.get_value(i.iter, 3)
                alert = widget.get_alert()
                alert.show()
                standalone = widget.get_standalone_widget()
                standalone.set_ringing(True)
                self.emit("show-standalone", widget)
        return True

    def _on_notification_activated(self, notif, action, data):
        win = self.get_toplevel()
        win.show_clock(self)

    def _on_item_activated(self, iconview, path):
        alarm = self.liststore[path][3]
        self.emit("show-standalone", alarm)

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
        alarms = []
        for path in selection:
            alarms.append(self.liststore[path][-1])
        self.delete_alarms(alarms)

    def load_alarms(self):
        self.alarms = self.storage.load()
        for alarm in self.alarms:
            self.add_alarm_widget(alarm)

    def add_alarm(self, alarm):
        self.alarms.append(alarm)
        self.storage.save(self.alarms)
        self.add_alarm_widget(alarm)
        self.show_all()

    def add_alarm_widget(self, alarm):
        alert = Alert("alarm-clock-elapsed", alarm.name,
                      self._on_notification_activated)
        widget = AlarmWidget(self, alarm, alert)
        label = GLib.markup_escape_text(alarm.name)
        view_iter = self.liststore.append([False,
                                           widget.get_pixbuf(),
                                           "<b>%s</b>" % label,
                                           widget,
                                           alarm])
        self.notify("can-select")

    def update_alarm(self, old_alarm, new_alarm):
        i = self.alarms.index(old_alarm)
        self.alarms[i] = new_alarm
        self.storage.save(self.alarms)

    def delete_alarms(self, alarms):
        for a in alarms:
            self.alarms.remove(a)
        self.storage.save(self.alarms)
        self.iconview.unselect_all()
        self.liststore.clear()
        self.load_alarms()
        self.notify("can-select")

    def open_new_dialog(self):
        window = AlarmDialog(self.get_toplevel())
        window.connect("response", self._on_dialog_response)
        window.show_all()

    def _on_dialog_response(self, dialog, response):
        if response == 1:
            alarm = dialog.get_alarm_item()
            self.add_alarm(alarm)
        dialog.destroy()


class StandaloneAlarm(Gtk.Box):
    def __init__(self, view, alarm, alert):
        Gtk.Box.__init__(self, orientation=Gtk.Orientation.VERTICAL)
        self.view = view
        self.alarm = alarm
        self.alert = alert
        self.can_edit = True

        self.timebox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)

        self.alarm_label = Gtk.Label()
        self.alarm_label.set_alignment(0.5, 0.5)
        self.timebox.pack_start(self.alarm_label, True, True, 0)

        self.repeat_label = Gtk.Label()
        self.repeat_label.set_alignment(0.5, 0.5)
        self.timebox.pack_start(self.repeat_label, True, True, 0)

        self.buttons = Gtk.Box()
        self.leftButton = Gtk.Button()
        self.leftButton.get_style_context().add_class("clocks-stop")
        self.leftButton.set_size_request(200, -1)
        self.leftLabel = Gtk.Label()
        self.leftButton.add(self.leftLabel)
        self.rightButton = Gtk.Button()
        self.rightButton.set_size_request(200, -1)
        self.rightLabel = Gtk.Label()
        self.rightButton.add(self.rightLabel)

        self.buttons.pack_start(self.leftButton, True, True, 0)
        self.buttons.pack_start(Gtk.Box(), True, True, 24)
        self.buttons.pack_start(self.rightButton, True, True, 0)

        self.leftLabel.set_markup("<span font_desc=\"18.0\">%s</span>" % (_("Stop")))
        self.leftLabel.set_padding(6, 0)
        self.rightLabel.set_markup("<span font_desc=\"18.0\">%s</span>" % (_("Snooze")))
        self.rightLabel.set_padding(6, 0)

        self.leftButton.connect('clicked', self._on_stop_clicked)
        self.rightButton.connect('clicked', self._on_snooze_clicked)

        self.timebox.pack_start(self.buttons, True, True, 48)

        hbox = Gtk.Box()
        hbox.set_homogeneous(False)

        hbox.pack_start(Gtk.Label(), True, True, 0)
        hbox.pack_start(self.timebox, False, False, 0)
        hbox.pack_start(Gtk.Label(), True, True, 0)

        self.pack_start(Gtk.Label(), True, True, 0)
        self.pack_start(hbox, False, False, 0)
        self.pack_start(Gtk.Label(), True, True, 0)

        self.update()

        self.show_all()
        self.set_ringing(False)

    def _on_stop_clicked(self, button):
        self.alert.stop()

    def _on_snooze_clicked(self, button):
        # Add 9 minutes, but without saving the change permanently
        self.alarm.time += timedelta(minutes=9)
        self.alarm.expired = False
        self.alert.stop()

    def get_name(self):
        name = self.alarm.get_alarm_name()
        return GLib.markup_escape_text(name)

    def set_ringing(self, show):
        self.buttons.set_visible(show)

    def update(self):
        timestr = self.alarm.get_time_as_string()
        repeat = self.alarm.get_alarm_repeat_string()
        self.alarm_label.set_markup(
            "<span size='72000' color='dimgray'><b>%s</b></span>" % timestr)
        self.repeat_label.set_markup(
            "<span size='large' color='dimgray'><b>%s</b></span>" % repeat)

    def open_edit_dialog(self):
        window = AlarmDialog(self.get_toplevel(), self.alarm)
        window.connect("response", self._on_dialog_response)
        window.show_all()

    def _on_dialog_response(self, dialog, response):
        if response == 1:
            new_alarm = dialog.get_alarm_item()
            self.view.update_alarm(self.alarm, new_alarm)
            self.update()
        dialog.destroy()
