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
import json
from datetime import timedelta
from gi.repository import GLib, GObject, GdkPixbuf, Gtk
from clocks import Clock
from utils import Alert, Dirs, LocalizedWeekdays, SystemSettings, TimeString, WallClock
from widgets import SelectableIconView, ContentView


wallclock = WallClock.get_default()


class AlarmsStorage:
    def __init__(self):
        self.filename = os.path.join(Dirs.get_user_data_dir(), "alarms.json")

    def save(self, alarms):
        alarm_list = []
        for a in alarms:
            d = {
                "name": a.name,
                "hour": a.hour,
                "minute": a.minute,
                "days": a.days,
                "active": a.active
            }
            alarm_list.append(d)
        with open(self.filename, "wb") as f:
            json.dump(alarm_list, f, ensure_ascii=False)

    def load(self):
        alarms = []
        try:
            with open(self.filename, "rb") as f:
                alarm_list = json.load(f)
            for a in alarm_list:
                try:
                    n, h, m, d = (a['name'], int(a['hour']), int(a['minute']), a['days'])
                    # support the old format that didn't have the active key
                    active = a['active'] if a.has_key('active') else True
                except:
                    # skip alarms which do not have the required fields
                    continue
                alarm = AlarmItem(n.encode("utf-8"), h, m, d, active)
                alarms.append(alarm)
        except IOError as e:
            if e.errno == errno.ENOENT:
                # File does not exist yet, that's ok
                pass
        return alarms


class AlarmItem:
    EVERY_DAY = [0, 1, 2, 3, 4, 5, 6]

    class State:
        READY = 0
        RINGING = 1
        SNOOZING = 2

    def __init__(self, name, hour, minute, days, active):
        self.name = name
        self.hour = hour
        self.minute = minute
        self.days = days  # list of numbers, 0 == Monday
        self.active = active

        self._reset()

        self.alarm_time_string = TimeString.format_time(self.alarm_time)
        self.alarm_repeat_string = self._get_alarm_repeat_string()
        self.alert = Alert("alarm-clock-elapsed", name)

    # two alarms are equal if they have the same name, time and days,
    # the active attribute doesn't matter
    def __eq__(self, other):
        return self.name == other.name and \
            self.hour == other.hour and \
            self.minute == other.minute and \
            self.days == other.days

    def __ne__(self, other):
        return not self.__eq__(other)

    def _update_alarm_time(self):
        now = wallclock.datetime
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
        self.alarm_time = dt

    def _update_snooze_time(self, start_time):
        self.snooze_time = start_time + timedelta(minutes=9)

    def _get_alarm_repeat_string(self):
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

    def _reset(self):
        self._update_alarm_time()
        self._update_snooze_time(self.alarm_time)
        self.state = AlarmItem.State.READY

    def set_active(self, active):
        if active:
            self._reset()
        elif self.state == AlarmItem.State.RINGING:
            self.alert.stop()
        self.active = active

    def snooze(self):
        self.alert.stop()
        self.state = AlarmItem.State.SNOOZING

    def stop(self):
        self.alert.stop()
        self._update_snooze_time(self.alarm_time)
        self.state = AlarmItem.State.READY

    def check_expired(self):
        if wallclock.datetime >= self.alarm_time:
            self._update_snooze_time(self.alarm_time)
            self._update_alarm_time()
            self.state = AlarmItem.State.RINGING
            return True
        elif wallclock.datetime >= self.snooze_time:
            self._update_snooze_time(self.snooze_time)
            self.state = AlarmItem.State.RINGING
            return True
        else:
            return False


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
            h = alarm.hour
            m = alarm.minute
            name = alarm.name
            days = alarm.days
        else:
            t = wallclock.localtime
            h = t.tm_hour
            m = t.tm_min
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
            if h < 12:
                self.ampm.set_active(0)  # AM
            else:
                self.ampm.set_active(1)  # PM
                h -= 12
            if h == 0:
                h = 12
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
        # needed in case the first day of the week is not 0 (Monday)
        days.sort()
        # if no days were selected, create a daily alarm
        if not days:
            days = AlarmItem.EVERY_DAY
        alarm = AlarmItem(name, h, m, days, True)
        return alarm


class AlarmStandalone(Gtk.EventBox):
    def __init__(self, view):
        Gtk.EventBox.__init__(self)
        self.get_style_context().add_class('view')
        self.get_style_context().add_class('content-view')
        self.view = view
        self.can_edit = True

        self.alarm_label = Gtk.Label()
        self.alarm_label.set_hexpand(True)
        self.alarm_label.set_alignment(0.5, 0.5)
        self.alarm_label.set_halign(Gtk.Align.CENTER)

        self.repeat_label = Gtk.Label()
        self.repeat_label.set_alignment(0.5, 0.5)

        self.left_button = Gtk.Button()
        self.left_button.get_style_context().add_class("clocks-stop")
        self.left_button.set_size_request(200, -1)
        self.left_label = Gtk.Label()
        self.left_button.add(self.left_label)
        self.right_button = Gtk.Button()
        self.right_button.set_size_request(200, -1)
        self.right_label = Gtk.Label()
        self.right_button.add(self.right_label)
        self.left_label.set_markup("<span font_desc=\"18.0\">%s</span>" % (_("Stop")))
        self.left_label.set_padding(6, 0)
        self.right_label.set_markup("<span font_desc=\"18.0\">%s</span>" % (_("Snooze")))
        self.right_label.set_padding(6, 0)
        self.left_button.connect('clicked', self._on_stop_clicked)
        self.right_button.connect('clicked', self._on_snooze_clicked)

        self.switch = Gtk.Switch()
        self.switch.show()
        self.switch.set_halign(Gtk.Align.CENTER)
        self.switch.set_valign(Gtk.Align.START)
        self.switch.connect("notify::active", self._on_switch)

        self.buttons = Gtk.Box()
        self.buttons.show()
        self.buttons.set_halign(Gtk.Align.CENTER)
        self.buttons.set_valign(Gtk.Align.START)
        self.buttons.pack_start(self.left_button, True, True, 0)
        self.buttons.pack_start(Gtk.Label(), True, True, 12)
        self.buttons.pack_start(self.right_button, True, True, 0)

        self.controls_notebook = Gtk.Notebook()
        self.controls_notebook.set_margin_top(24)
        self.controls_notebook.set_show_tabs(False)
        self.controls_notebook.append_page(self.switch, None)
        self.controls_notebook.append_page(self.buttons, None)

        label_top = Gtk.Label()
        label_top.set_vexpand(True)
        label_bottom = Gtk.Label()
        label_bottom.set_vexpand(True)

        label_padding = Gtk.Label()
        label_padding.set_size_request(-1, 30)

        self.grid = Gtk.Grid()
        self.grid.set_orientation(Gtk.Orientation.VERTICAL)
        self.grid.add(label_top)
        self.grid.add(label_padding)
        self.grid.add(self.alarm_label)
        self.grid.add(self.repeat_label)
        self.grid.add(self.controls_notebook)
        self.grid.add(label_bottom)

        self.add(self.grid)

        self.set_alarm(None)

    def set_alarm(self, alarm):
        self.alarm = alarm
        if alarm:
            is_ready = alarm.state == AlarmItem.State.READY
            is_ringing = alarm.state == AlarmItem.State.RINGING
            self.update()
            self.left_button.set_sensitive(not is_ready)
            self.right_button.set_sensitive(is_ringing)
            self.switch.set_active(alarm.active)
            self.show_all()
            self.controls_notebook.set_current_page(0 if is_ready else 1)

    def _on_stop_clicked(self, button):
        self.alarm.stop()
        self.controls_notebook.set_current_page(0)

    def _on_snooze_clicked(self, button):
        self.right_button.set_sensitive(False)
        self.alarm.snooze()

    def _on_switch(self, switch, param):
        switch_active = switch.get_active()
        if self.alarm.active != switch_active:
            self.alarm.set_active(switch_active)
            self.view.save_alarms()

    def get_name(self):
        name = self.alarm.name
        return GLib.markup_escape_text(name)

    def update(self):
        if self.alarm:
            timestr = self.alarm.alarm_time_string
            repeat = self.alarm.alarm_repeat_string
            self.alarm_label.set_markup(
                "<span size='72000' color='dimgray'><b>%s</b></span>" % timestr)
            self.repeat_label.set_markup(
                "<span size='large' color='dimgray'><b>%s</b></span>" % repeat)

    def open_edit_dialog(self):
        # implicitely disable, we do not want to ring while editing.
        self.edited_active = self.alarm.active
        self.alarm.set_active(False)
        window = AlarmDialog(self.get_toplevel(), self.alarm)
        window.connect("response", self._on_dialog_response)
        window.show_all()

    def _on_dialog_response(self, dialog, response):
        if response == 1:
            new_alarm = dialog.get_alarm_item()
            alarm = self.view.replace_alarm(self.alarm, new_alarm)
            self.set_alarm(alarm)
            self.update()
        else:
            # edited alarms are always active, instead on cancel
            # we restore the previous state
            self.alarm.set_active(self.edited_active)
        dialog.destroy()


class Alarm(Clock):
    def __init__(self):
        # Translators: "New" refers to an alarm
        Clock.__init__(self, _("Alarm"), _("New"))

        self.notebook = Gtk.Notebook()
        self.notebook.set_show_tabs(False)
        self.notebook.set_show_border(False)
        self.add(self.notebook)

        self.liststore = Gtk.ListStore(bool, str, object)
        self.iconview = SelectableIconView(self.liststore, 0, 1, self._thumb_data_func)
        self.iconview.connect("item-activated", self._on_item_activated)
        self.iconview.connect("selection-changed", self._on_selection_changed)

        contentview = ContentView(self.iconview,
                                  "alarm-symbolic",
                                  _("Select <b>New</b> to add an alarm"))
        self.notebook.append_page(contentview, None)

        self.storage = AlarmsStorage()

        self.load_alarms()
        self.show_all()

        self.standalone = AlarmStandalone(self)
        self.notebook.append_page(self.standalone, None)

        wallclock.connect("time-changed", self._check_alarms)

    def _thumb_data_func(self, view, cell, store, i, data):
        alarm = store.get_value(i, 2)
        cell.text = alarm.alarm_time_string
        cell.subtext = alarm.alarm_repeat_string
        if alarm.active:
            cell.css_class = "active"
        else:
            cell.css_class = "inactive"

    def set_mode(self, mode):
        self.mode = mode
        if mode is Clock.Mode.NORMAL:
            if self.standalone.alarm and \
                    self.standalone.alarm.state == AlarmItem.State.RINGING:
                self.standalone.alarm.stop()
            self.notebook.set_current_page(0)
            self.iconview.set_selection_mode(False)
        elif mode is Clock.Mode.STANDALONE:
            self.notebook.set_current_page(1)
        elif mode is Clock.Mode.SELECTION:
            self.iconview.set_selection_mode(True)

    @GObject.Signal
    def alarm_ringing(self):
        self.set_mode(Clock.Mode.STANDALONE)

    def _check_alarms(self, *args):
        for a in self.alarms:
            if a.active and a.check_expired():
                self.standalone.set_alarm(a)
                a.alert.show()
                self.emit("alarm-ringing")

    def _on_item_activated(self, iconview, path):
        alarm = self.liststore[path][2]
        self.standalone.set_alarm(alarm)
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
        alarms = [self.liststore[path][2] for path in selection]
        self.delete_alarms(alarms)
        self.emit("selection-changed")

    def load_alarms(self):
        self.alarms = self.storage.load()
        for alarm in self.alarms:
            self._add_alarm_item(alarm)

    def save_alarms(self):
        self.storage.save(self.alarms)
        self.liststore.clear()
        self.load_alarms()
        self.notify("can-select")

    def add_alarm(self, alarm):
        if alarm in self.alarms:
            self.replace_alarm(alarm, alarm)
        else:
            self.alarms.append(alarm)
            self._add_alarm_item(alarm)
            self.show_all()
            self.save_alarms()

    def _add_alarm_item(self, alarm):
        label = GLib.markup_escape_text(alarm.name)
        self.liststore.append([False, "<b>%s</b>" % label, alarm])

    def replace_alarm(self, old_alarm, new_alarm):
        i = self.alarms.index(old_alarm)
        self.alarms[i] = new_alarm
        self.save_alarms()
        return self.alarms[i]

    def delete_alarms(self, alarms):
        self.alarms = [a for a in self.alarms if a not in alarms]
        self.save_alarms()

    def open_new_dialog(self):
        window = AlarmDialog(self.get_toplevel())
        window.connect("response", self._on_dialog_response)
        window.show_all()

    def _on_dialog_response(self, dialog, response):
        if response == 1:
            alarm = dialog.get_alarm_item()
            self.add_alarm(alarm)
        dialog.destroy()
