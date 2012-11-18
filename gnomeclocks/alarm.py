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
from gi.repository import GLib, GObject, Gtk, GdkPixbuf
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
                "days": a.days
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
                try:
                    n, h, m, d = (a['name'], int(a['hour']), int(a['minute']), a['days'])
                except:
                    # skip alarms which do not have the required fields
                    continue
                alarm = AlarmItem(n.encode("utf-8"), h, m, d)
                alarms.append(alarm)
        except IOError as e:
            if e.errno == errno.ENOENT:
                # File does not exist yet, that's ok
                pass

        return alarms


class AlarmItem:
    EVERY_DAY = [0, 1, 2, 3, 4, 5, 6]

    def __init__(self, name=None, hour=None, minute=None, days=EVERY_DAY):
        self.update(name=name, hour=hour, minute=minute, days=days)
        self.alert = Alert("alarm-clock-elapsed", name)

    def update(self, name=None, hour=None, minute=None, days=EVERY_DAY):
        self.name = name
        self.hour = hour
        self.minute = minute
        self.days = days # list of numbers, 0 == Monday

        # an alarm without any day makes no sense...
        if not self.days:
            self.days = AlarmItem.EVERY_DAY

        self.time = None
        self.snooze_time = None
        self.is_snoozing = False

        if not hour == None and not minute == None:
            self._update_expiration_time()
            self._reset_snooze(self.time)

    def _update_expiration_time(self):
        now = datetime.now()
        dt = now.replace(hour=self.hour, minute=self.minute, second=0, microsecond=0)
        # check if it can ring later today
        if dt.weekday() not in self.days or dt <= now:
            # otherwise if it can ring this week
            next_days = [d for d in self.days if d > dt.weekday()]
            if next_days:
                dt += timedelta(days=(next_days[0] - dt.weekday()))
            # otherwise next week
            else:
                dt += timedelta(weeks=1, days=(self.days[0] - dt.weekday()))
        self.time = dt

    def _reset_snooze(self, start_time):
        self.snooze_time = start_time + timedelta(minutes=9)
        self.is_snoozing = False

    def snooze(self):
        self.is_snoozing = True
        self.alert.stop()

    def stop(self):
        self._reset_snooze(self.time)
        self.alert.stop()

    def get_time_as_string(self):
        if SystemSettings.get_clock_format() == "12h":
            return self.time.strftime("%I:%M %p")
        else:
            return self.time.strftime("%H:%M")

    def get_alarm_repeat_string(self):
        n = len(self.days)
        if n == 0:
            return ""
        elif n == 1:
            return LocalizedWeekdays.get_plural(self.days[0])
        elif n == 7:
            return _("Every day")
        elif self.days == [0, 1, 2, 3, 4]:
            return _("Weekdays")
        else:
            days = []
            for i in range(7):
                day_num = (LocalizedWeekdays.first_weekday() + i) % 7
                if day_num in self.days:
                    days.append(LocalizedWeekdays.get_abbr(day_num))
            return ", ".join(days)

    def check_expired(self):
        t = datetime.now()
        if t > self.time:
            self.alert.show()
            self._reset_snooze(self.time)
            self._update_expiration_time()
            return True
        elif self.is_snoozing and t > self.snooze_time:
            self._reset_snooze(self.snooze_time)
            return True
        else:
            return False

    def get_is_light(self):
        return self.hour > 7 and self.hour < 19


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
            days = alarm.days
        else:
            t = time.localtime()
            h = t.tm_hour
            m = t.tm_min
            p = time.strftime("%p", t)
            name = _("New Alarm")
            days = []

        # Translators: "Time" in this context is the time an alarm
        # is set to go off (days, hours, minutes etc.)
        label = Gtk.Label(_("Time"))
        label.set_alignment(1.0, 0.5)
        grid.attach(label, 0, 0, 1, 1)

        self.hourselect = Gtk.SpinButton()
        self.hourselect.set_numeric(True)
        self.hourselect.set_increments(1.0, 1.0)
        self.hourselect.set_wrap(True)
        grid.attach(self.hourselect, 1, 0, 1, 1)

        label = Gtk.Label(": ")
        label.set_alignment(0.5, 0.5)
        grid.attach(label, 2, 0, 1, 1)

        self.minuteselect = Gtk.SpinButton()
        self.minuteselect.set_numeric(True)
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
        for i in range(7):
            day_num = (LocalizedWeekdays.first_weekday() + i) % 7
            day_name = LocalizedWeekdays.get_abbr(day_num)
            btn = Gtk.ToggleButton(label=day_name)
            btn.data = day_num
            if btn.data in days:
                btn.set_active(True)
            box.pack_start(btn, True, True, 0)
            self.day_buttons.append(btn)
        grid.attach(box, 1, 2, gridcols - 1, 1)

    def _show_leading_zeros(self, spin_button):
        spin_button.set_text('{:02d}'.format(spin_button.get_value_as_int()))
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
        days = []
        for btn in self.day_buttons:
            if btn.get_active():
                days.append(btn.data)
        alarm = AlarmItem(name, h, m, days)
        return alarm


class AlarmThumbnail():
    def __init__(self, alarm):
        self.alarm = alarm
        timestr = alarm.get_time_as_string()
        repeat = alarm.get_alarm_repeat_string()
        self.drawing = DigitalClockDrawing()
        is_light = self.alarm.get_is_light()
        if is_light:
            img = os.path.join(Dirs.get_image_dir(), "cities", "day.png")
        else:
            img = os.path.join(Dirs.get_image_dir(), "cities", "night.png")
        self.drawing.render(timestr, img, is_light, repeat)

    def get_alarm(self):
        return self.alarm

    def get_pixbuf(self):
        return self.drawing.pixbuf


class AlarmStandalone(Gtk.EventBox):
    def __init__(self, view):
        Gtk.EventBox.__init__(self)
        self.get_style_context().add_class('view')
        self.get_style_context().add_class('content-view')
        self.view = view
        self.can_edit = True

        self.vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.add(self.vbox)

        time_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)

        self.alarm_label = Gtk.Label()
        self.alarm_label.set_alignment(0.5, 0.5)
        time_box.pack_start(self.alarm_label, True, True, 0)

        self.repeat_label = Gtk.Label()
        self.repeat_label.set_alignment(0.5, 0.5)
        time_box.pack_start(self.repeat_label, True, True, 0)

        self.buttons = Gtk.Box()
        self.left_button = Gtk.Button()
        self.left_button.get_style_context().add_class("clocks-stop")
        self.left_button.set_size_request(200, -1)
        self.left_label = Gtk.Label()
        self.left_button.add(self.left_label)
        self.right_button = Gtk.Button()
        self.right_button.set_size_request(200, -1)
        self.right_label = Gtk.Label()
        self.right_button.add(self.right_label)

        self.buttons.pack_start(self.left_button, True, True, 0)
        self.buttons.pack_start(Gtk.Box(), True, True, 24)
        self.buttons.pack_start(self.right_button, True, True, 0)

        self.left_label.set_markup("<span font_desc=\"18.0\">%s</span>" % (_("Stop")))
        self.left_label.set_padding(6, 0)
        self.right_label.set_markup("<span font_desc=\"18.0\">%s</span>" % (_("Snooze")))
        self.right_label.set_padding(6, 0)

        self.left_button.connect('clicked', self._on_stop_clicked)
        self.right_button.connect('clicked', self._on_snooze_clicked)

        time_box.pack_start(self.buttons, True, True, 48)

        hbox = Gtk.Box()
        hbox.set_homogeneous(False)

        hbox.pack_start(Gtk.Label(), True, True, 0)
        hbox.pack_start(time_box, False, False, 0)
        hbox.pack_start(Gtk.Label(), True, True, 0)

        self.vbox.pack_start(Gtk.Label(), True, True, 0)
        self.vbox.pack_start(hbox, False, False, 0)
        self.vbox.pack_start(Gtk.Label(), True, True, 0)

        self.set_alarm(None)

    def set_alarm(self, alarm, ringing=False):
        self.alarm = alarm
        if alarm:
            self.update()
            self.show_all()
            self.buttons.set_visible(ringing)

    def _on_stop_clicked(self, button):
        self.alarm.stop()

    def _on_snooze_clicked(self, button):
        self.alarm.snooze()

    def get_name(self):
        name = self.alarm.name
        return GLib.markup_escape_text(name)

    def update(self):
        if self.alarm:
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
            self.alarm = self.view.update_alarm(self.alarm, new_alarm)
            self.update()
        dialog.destroy()


class Alarm(Clock):
    def __init__(self):
        # Translators: "New" refers to an alarm
        Clock.__init__(self, _("Alarm"), _("New"))

        self.notebook = Gtk.Notebook()
        self.notebook.set_show_tabs(False)
        self.notebook.set_show_border(False)
        self.add(self.notebook)

        self.liststore = Gtk.ListStore(bool,
                                       GdkPixbuf.Pixbuf,
                                       str,
                                       GObject.TYPE_PYOBJECT)

        self.iconview = SelectableIconView(self.liststore, 0, 1, 2)

        contentview = ContentView(self.iconview,
                                  "alarm-symbolic",
                                  _("Select <b>New</b> to add an alarm"))
        self.notebook.append_page(contentview, None)

        self.iconview.connect("item-activated", self._on_item_activated)
        self.iconview.connect("selection-changed", self._on_selection_changed)

        self.storage = AlarmsStorage()

        self.load_alarms()
        self.show_all()

        self.standalone = AlarmStandalone(self)
        self.notebook.append_page(self.standalone, None)

        self.timeout_id = GLib.timeout_add(1000, self._check_alarms)

    def set_mode(self, mode):
        self.mode = mode
        if mode is Clock.Mode.NORMAL:
            self.iconview.unselect_all()
            self.notebook.set_current_page(0)
            self.iconview.set_selection_mode(False)
        elif mode is Clock.Mode.STANDALONE:
            self.notebook.set_current_page(1)
        elif mode is Clock.Mode.SELECTION:
            self.iconview.set_selection_mode(True)

    @GObject.Signal
    def alarm_ringing(self):
        self.set_mode(Clock.Mode.STANDALONE)

    def _check_alarms(self):
        for i in self.liststore:
            thumb = self.liststore.get_value(i.iter, 3)
            alarm = thumb.get_alarm()
            if alarm.check_expired():
                self.standalone.set_alarm(alarm, True)
                self.emit("alarm-ringing")
        return True

    def _on_item_activated(self, iconview, path):
        thumb = self.liststore[path][3]
        self.standalone.set_alarm(thumb.get_alarm())
        self.emit("item-activated")

    def _on_selection_changed(self, iconview):
        self.emit("selection-changed")

    @GObject.Property(type=bool, default=False)
    def can_select(self):
        return len(self.liststore) != 0

    def get_selection(self):
        return self.iconview.get_selection()

    def delete_selected(self):
        selection = self.get_selection()
        alarms = [self.liststore[path][3].get_alarm() for path in selection]
        self.delete_alarms(alarms)

    def load_alarms(self):
        self.alarms = self.storage.load()
        for alarm in self.alarms:
            self.add_alarm_thumbnail(alarm)

    def add_alarm(self, alarm):
        self.alarms.append(alarm)
        self.storage.save(self.alarms)
        self.add_alarm_thumbnail(alarm)
        self.show_all()

    def add_alarm_thumbnail(self, alarm):
        thumb = AlarmThumbnail(alarm)
        label = GLib.markup_escape_text(alarm.name)
        view_iter = self.liststore.append([False,
                                           thumb.get_pixbuf(),
                                           "<b>%s</b>" % label,
                                           thumb])
        self.notify("can-select")

    def update_alarm(self, old_alarm, new_alarm):
        i = self.alarms.index(old_alarm)
        self.alarms[i] = new_alarm
        self.storage.save(self.alarms)
        self.iconview.unselect_all()
        self.liststore.clear()
        self.load_alarms()
        self.notify("can-select")
        return self.alarms[i]

    def delete_alarms(self, alarms):
        self.alarms = [a for a in self.alarms if a not in alarms]
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
