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

import os
import errno
import time
import json
from gi.repository import GLib, GObject, Gio, Gtk, GdkPixbuf
from gi.repository import GWeather
from clocks import Clock
from utils import Dirs, SystemSettings
from widgets import DigitalClockDrawing, SelectableIconView, ContentView


class WorldClockStorage():
    def __init__(self):
        self.filename = os.path.join(Dirs.get_user_data_dir(), "clocks.json")
        self.world = GWeather.Location.new_world(True)

    def save(self, clocks):
        location_codes = [c.location.get_code() for c in clocks]
        f = open(self.filename, "wb")
        json.dump(location_codes, f)
        f.close()

    def load(self):
        clocks = []
        try:
            f = open(self.filename, "rb")
            location_codes = json.load(f)
            f.close()
            for l in location_codes:
                location = GWeather.Location.find_by_station_code(self.world, l)
                if location:
                    clock = DigitalClock(location)
                    clocks.append(clock)
        except IOError as e:
            if e.errno == errno.ENOENT:
                # File does not exist yet, that's ok
                pass

        return clocks


class NewWorldClockDialog(Gtk.Dialog):
    def __init__(self, parent):
        Gtk.Dialog.__init__(self, _("Add a New World Clock"), parent)
        self.set_transient_for(parent)
        self.set_modal(True)
        self.set_size_request(400, -1)
        self.set_border_width(3)
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        area = self.get_content_area()
        area.pack_start(box, True, True, 0)

        label = Gtk.Label(_("Search for a city:"))
        label.set_alignment(0.0, 0.5)

        world = GWeather.Location.new_world(True)
        self.entry = GWeather.LocationEntry.new(world)
        self.find_gicon = Gio.ThemedIcon.new_with_default_fallbacks(
            'edit-find-symbolic')
        self.clear_gicon = Gio.ThemedIcon.new_with_default_fallbacks(
            'edit-clear-symbolic')
        self.entry.set_icon_from_gicon(
            Gtk.EntryIconPosition.SECONDARY, self.find_gicon)
        self.entry.set_activates_default(True)

        self.add_buttons(Gtk.STOCK_CANCEL, 0, Gtk.STOCK_ADD, 1)
        self.set_default_response(1)
        self.set_response_sensitive(1, False)

        box.pack_start(label, False, False, 6)
        box.pack_start(self.entry, False, False, 3)
        box.set_border_width(5)

        self.entry.connect("activate", self._set_city)
        self.entry.connect("changed", self._set_city)
        self.entry.connect("icon-release", self._icon_released)
        self.show_all()

    def get_location(self):
        return self.entry.get_location()

    def _set_city(self, widget):
        location = self.entry.get_location()
        if self.entry.get_text() == '':
            self.entry.set_icon_from_gicon(
                Gtk.EntryIconPosition.SECONDARY, self.find_gicon)
        else:
            self.entry.set_icon_from_gicon(
                Gtk.EntryIconPosition.SECONDARY, self.clear_gicon)
        if location:
            self.set_response_sensitive(1, True)
        else:
            self.set_response_sensitive(1, False)

    def _icon_released(self, icon_pos, event, data):
        if self.entry.get_icon_gicon(
            Gtk.EntryIconPosition.SECONDARY) == self.clear_gicon:
            self.entry.set_text('')
            self.entry.set_icon_from_gicon(
              Gtk.EntryIconPosition.SECONDARY, self.find_gicon)
            self.set_response_sensitive(1, False)


class DigitalClock():
    def __init__(self, location):
        self.location = location
        self._last_sunrise = time.strptime("197007:00", "%Y%H:%M")
        self.sunrise = self._last_sunrise
        self._last_sunset = time.strptime("197019:00", "%Y%H:%M")
        self.sunset = self._last_sunset
        self.get_sunrise_sunset()

        self.path = None
        self.list_store = None

        timezone = self.location.get_timezone()
        self.offset = timezone.get_offset() * 60
        self._last_time = None
        self.drawing = DigitalClockDrawing()
        self.standalone = None
        self.update()
        self.timeout = GObject.timeout_add(1000, self.update)

    def stop_update(self):
        GObject.source_remove(self.timeout)
        self.timeout = 0

    def get_local_time(self, secs):
        t = secs + time.timezone + self.offset
        t = time.localtime(t)
        return t

    def update(self):
        systemClockFormat = SystemSettings.get_clock_format()
        if systemClockFormat == '12h':
            t = time.strftime("%I:%M %p", self.get_local_time(time.time()))
        else:
            t = time.strftime("%H:%M", self.get_local_time(time.time()))
        if t.startswith("0"):
            t = t[1:]
        if not t == self._last_time \
                or not self.sunrise == self._last_sunrise \
                or not self.sunset == self._last_sunset:
            local_time = self.get_local_time(time.time())
            isDay = self.get_is_light(local_time, self.sunrise, self.sunset)
            if isDay:
                img = os.path.join(Dirs.get_image_dir(), "cities", "day.png")
            else:
                img = os.path.join(Dirs.get_image_dir(), "cities", "night.png")
            day = self.get_day()
            if day == "Today":
                self.drawing.render(t, img, isDay)
            else:
                self.drawing.render(t, img, isDay, day)
            if self.path and self.list_store:
                self.list_store[self.path][1] = self.drawing.pixbuf
            if self.standalone:
                self.standalone.update(img, t, self.sunrise, self.sunset)

        self._last_time = t
        return True

    def get_sunrise_sunset(self):
        world = GWeather.Location.new_world(True)
        self.weather = GWeather.Info(location=self.location, world=world)
        self.weather.connect('updated', self._on_weather_updated)
        self.weather.update()

    def _on_weather_updated(self, weather):
        # returned as the time here
        ok, sunrise = weather.get_value_sunrise()
        ok, sunset = weather.get_value_sunset()
        self._last_sunrise = self.sunrise
        self._last_sunset = self.sunset
        self.sunrise = self.get_local_time(sunrise)
        self.sunset = self.get_local_time(sunset)
        self.update()

    def get_pixbuf(self):
        return self.drawing.pixbuf

    def get_standalone_widget(self):
        if not self.standalone:
            self.standalone = StandaloneClock(self.location, self.sunrise, self.sunset)
        self.update()
        return self.standalone

    def get_day(self):
        clock_time_day = self.get_local_time(time.time()).tm_yday
        local_time_day = time.localtime().tm_yday

        if clock_time_day == local_time_day:
            return "Today"
        # if its 31st Dec here and 1st Jan there, clock_time_day = 1,
        # local_time_day = 365/366
        # if its 1st Jan here and 31st Dec there, clock_time_day = 365/366,
        # local_time_day = 1
        elif clock_time_day > local_time_day:
            if local_time_day == 1:
                return "Yesterday"
            else:
                return "Tomorrow"
        elif clock_time_day < local_time_day:
            if clock_time_day == 1:
                return "Tomorrow"
            else:
                return "Yesterday"

    def get_is_light(self, current, sunrise, sunset):
        if current.tm_hour < sunrise.tm_hour \
                or current.tm_hour > sunset.tm_hour:
            return False
        elif current.tm_hour > sunrise.tm_hour \
                and current.tm_hour < sunset.tm_hour:
            return True
        elif current.tm_hour == sunrise.tm_hour:
            if current.tm_min >= sunrise.tm_min:
                return True
            else:
                return False
        elif current.tm_hour == sunset.tm_hour:
            if current.tm_min <= sunrise.tm_min:
                return True
            else:
                return False

    def set_path(self, list_store, path):
        self.path = path
        self.list_store = list_store


class World(Clock):
    def __init__(self):
        Clock.__init__(self, _("World"), True, True)

        self.liststore = Gtk.ListStore(bool,
                                       GdkPixbuf.Pixbuf,
                                       str,
                                       GObject.TYPE_PYOBJECT)

        self.iconview = SelectableIconView(self.liststore, 0, 1, 2)

        contentview = ContentView(self.iconview,
                "document-open-recent-symbolic",
                 _("Select <b>New</b> to add a world clock"))
        self.add(contentview)

        self.iconview.connect("item-activated", self._on_item_activated)
        self.iconview.connect("selection-changed", self._on_selection_changed)

        self.storage = WorldClockStorage()
        self.clocks = []
        self.load_clocks()
        self.show_all()

    def _on_item_activated(self, iconview, path):
        d = self.liststore[path][3]
        self.emit("show-standalone", d)

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
        self.clocks = self.storage.load()
        for clock in self.clocks:
            self.add_clock_widget(clock)

    def add_clock(self, location):
        for c in self.clocks:
            if c.location.get_code() == location.get_code():
                # duplicate
                return
        clock = DigitalClock(location)
        self.clocks.append(clock)
        self.storage.save(self.clocks)
        self.add_clock_widget(clock)
        self.show_all()

    def add_clock_widget(self, clock):
        name = clock.location.get_city_name()
        label = GLib.markup_escape_text(name)
        view_iter = self.liststore.append([False,
                                           clock.get_pixbuf(),
                                           "<b>%s</b>" % label,
                                           clock])
        path = self.liststore.get_path(view_iter)
        clock.set_path(self.liststore, path)
        self.notify("can-select")

    def delete_clocks(self, clocks):
        for c in clocks:
            c.stop_update()
            self.clocks.remove(c)
        self.storage.save(self.clocks)
        self.iconview.unselect_all()
        self.liststore.clear()
        self.load_clocks()
        self.notify("can-select")

    def open_new_dialog(self):
        window = NewWorldClockDialog(self.get_toplevel())
        window.connect("response", self._on_dialog_response)
        window.show_all()

    def _on_dialog_response(self, dialog, response):
        if response == 1:
            l = dialog.get_location()
            self.add_clock(l)
        dialog.destroy()


class StandaloneClock(Gtk.Box):
    def __init__(self, location, sunrise, sunset):
        Gtk.Box.__init__(self, orientation=Gtk.Orientation.VERTICAL)
        self.location = location
        self.can_edit = False
        #self.img = Gtk.Image()
        #self.city_label = Gtk.Label()
        #label = GLib.markup_escape_text(location.get_city_name())
        #self.city_label.set_markup("<b>%s</b>" % label)
        self.time_label = Gtk.Label()
        self.sunrise = sunrise
        self.sunset = sunset

        self.systemClockFormat = None

        #imagebox = Gtk.VBox()
        #imagebox.pack_start(self.img, False, False, 0)
        #imagebox.pack_start(self.city_label, False, False, 0)
        #imagebox.set_size_request(230, 230)

        self.timebox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.time_label.set_alignment(0.0, 0.5)
        self.timebox.pack_start(self.time_label, True, True, 0)

        self.hbox = hbox = Gtk.Box()
        self.hbox.set_homogeneous(False)

        self.hbox.pack_start(Gtk.Label(), True, True, 0)
        # self.hbox.pack_start(imagebox, False, False, 0)
        # self.hbox.pack_start(Gtk.Label(), False, False, 30)
        self.hbox.pack_start(self.timebox, False, False, 0)
        self.hbox.pack_start(Gtk.Label(), True, True, 0)

        self.pack_start(Gtk.Label(), True, True, 25)
        self.pack_start(hbox, False, False, 0)
        self.pack_start(Gtk.Label(), True, True, 0)

        sunrise_label = Gtk.Label()
        sunrise_label.set_markup(
            "<span size ='large' color='dimgray'>%s</span>" % (_("Sunrise")))
        sunrise_label.set_alignment(1.0, 0.5)
        self.sunrise_time_label = Gtk.Label()
        self.sunrise_time_label.set_alignment(0.0, 0.5)
        sunrise_hbox = Gtk.Box(True, 9)
        sunrise_hbox.pack_start(sunrise_label, False, False, 0)
        sunrise_hbox.pack_start(self.sunrise_time_label, False, False, 0)

        sunset_label = Gtk.Label()
        sunset_label.set_markup(
            "<span size ='large' color='dimgray'>%s</span>" % (_("Sunset")))
        sunset_label.set_alignment(1.0, 0.5)
        self.sunset_time_label = Gtk.Label()
        self.sunset_time_label.set_alignment(0.0, 0.5)
        sunset_hbox = Gtk.Box(True, 9)
        sunset_hbox.pack_start(sunset_label, False, False, 0)
        sunset_hbox.pack_start(self.sunset_time_label, False, False, 0)

        sunbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        sunbox.set_homogeneous(True)
        sunbox.set_spacing(3)
        sunbox.pack_start(sunrise_hbox, False, False, 3)
        sunbox.pack_start(sunset_hbox, False, False, 3)

        hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        hbox.pack_start(Gtk.Label(), True, True, 0)
        hbox.pack_start(sunbox, False, False, 0)
        hbox.pack_start(Gtk.Label(), True, True, 0)
        self.pack_end(hbox, False, False, 30)

        self.show_all()

    def get_name(self):
        return GLib.markup_escape_text(self.location.get_city_name())

    def update(self, img, text, sunrise, sunset):
        size = 72000  # FIXME: (self.get_allocation().height / 300) * 72000
        #if img:
        #    pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_size(img, 500, 380)
        #    pixbuf = pixbuf.new_subpixbuf(0, 0, 208, 208)
        #    self.img.set_from_pixbuf(pixbuf)
        self.time_label.set_markup(
            "<span size='%i' color='dimgray'><b>%s</b></span>" % (size, text))
        systemClockFormat = SystemSettings.get_clock_format()
        if systemClockFormat != self.systemClockFormat or \
                sunrise != self.sunrise or sunset != self.sunset:
            self.sunrise = sunrise
            self.sunset = sunset
            if systemClockFormat == "12h":
                sunrise_str = time.strftime("%I:%M %p", sunrise)
                sunset_str = time.strftime("%I:%M %p", sunset)
            else:
                sunrise_str = time.strftime("%H:%M", sunrise)
                sunset_str = time.strftime("%H:%M", sunset)
            if sunrise_str.startswith("0"):
                sunrise_str = sunrise_str[1:]
            if sunset_str.startswith("0"):
                sunset_str = sunset_str[1:]
            self.sunrise_time_label.set_markup(
                "<span size ='large'>%s</span>" % sunrise_str)
            self.sunset_time_label.set_markup(
                "<span size ='large'>%s</span>" % sunset_str)
        self.systemClockFormat = systemClockFormat
