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
import time
from gi.repository import GLib, Gio, GdkPixbuf, Gtk
from gi.repository import GWeather
from .clocks import Clock
from .utils import Dirs, TimeString, WallClock
from .widgets import Toolbar, ToolButton, SymbolicToolButton, SelectableIconView, ContentView


# keep the GWeather world around as a singletom, otherwise
# if is garbage collected get_city_name etc fail.
gweather_world = GWeather.Location.new_world(True)
wallclock = WallClock.get_default()


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

        self.entry = GWeather.LocationEntry.new(gweather_world)
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


class ClockItem:
    def __init__(self, location):
        self.location = location
        self.name = self._get_location_name()

        weather_timezone = self.location.get_timezone()
        timezone = GLib.TimeZone.new(weather_timezone.get_tzid())
        i = timezone.find_interval(GLib.TimeType.UNIVERSAL, wallclock.time)
        location_offset = timezone.get_offset(i)

        timezone = GLib.TimeZone.new_local()
        i = timezone.find_interval(GLib.TimeType.UNIVERSAL, wallclock.time)
        here_offset = timezone.get_offset(i)

        self.offset = location_offset - here_offset

        self.sunrise = None
        self.sunset = None
        self.sunrise_string = None
        self.sunset_string = None

        self._update_sunrise_sunset()

        self.tick()

    def _get_location_name(self):
        nation = self.location
        while nation and nation.get_level() != GWeather.LocationLevel.COUNTRY:
            nation = nation.get_parent()
        if nation:
            return self.location.get_city_name() + ', ' + nation.get_name()
        else:
            return self.location.get_city_name()

    def _get_location_time(self, secs=None):
        if not secs:
            secs = wallclock.time
        t = secs + self.offset
        t = time.localtime(t)
        return t

    def _get_day_string(self):
        clock_time_day = self.location_time.tm_yday
        local_time_day = wallclock.localtime.tm_yday

        # if its 31st Dec here and 1st Jan there, clock_time_day = 1,
        # local_time_day = 365/366
        # if its 1st Jan here and 31st Dec there, clock_time_day = 365/366,
        # local_time_day = 1
        if clock_time_day > local_time_day:
            if local_time_day == 1:
                return _("Yesterday")
            else:
                return _("Tomorrow")
        elif clock_time_day < local_time_day:
            if clock_time_day == 1:
                return _("Tomorrow")
            else:
                return _("Yesterday")
        else:
            return ""  # today

    def _update_sunrise_sunset(self):
        self.weather = GWeather.Info(location=self.location, world=gweather_world)
        # We don't need to update self.weather, we're using only astronomical data
        # and that's offline
        ok1, sunrise = self.weather.get_value_sunrise()
        ok2, sunset = self.weather.get_value_sunset()
        self.is_light = self.weather.is_daytime()
        if ok1 and ok2:
            self.sunrise = self._get_location_time(sunrise)
            self.sunset = self._get_location_time(sunset)
            self.sunrise_string = TimeString.format_time(self.sunrise)
            self.sunset_string = TimeString.format_time(self.sunset)

    def tick(self):
        self.location_time = self._get_location_time()
        self.time_string = TimeString.format_time(self.location_time)
        self.day_string = self._get_day_string()
        self._update_sunrise_sunset()

    def serialize(self):
        return {"location": self.location.serialize()}


class WorldStandalone(Gtk.EventBox):
    def __init__(self):
        Gtk.EventBox.__init__(self)
        self.get_style_context().add_class('view')
        self.get_style_context().add_class('content-view')
        self.can_edit = False

        self.time_label = Gtk.Label()
        self.time_label.set_hexpand(True)
        self.day_label = Gtk.Label()

        sunrise_label = Gtk.Label()
        sunrise_label.set_markup(
            "<span size ='large' color='dimgray'>%s</span>" % (_("Sunrise")))
        self.sunrise_time_label = Gtk.Label()
        sunset_label = Gtk.Label()
        sunset_label.set_markup(
            "<span size ='large' color='dimgray'>%s</span>" % (_("Sunset")))
        self.sunset_time_label = Gtk.Label()

        self.sun_grid = Gtk.Grid()
        self.sun_grid.set_column_homogeneous(False)
        self.sun_grid.set_column_spacing(12)
        self.sun_grid.attach(sunrise_label, 1, 0, 1, 1)
        self.sun_grid.attach(self.sunrise_time_label, 2, 0, 1, 1)
        self.sun_grid.attach(sunset_label, 1, 1, 1, 1)
        self.sun_grid.attach(self.sunset_time_label, 2, 1, 1, 1)
        self.sun_grid.set_margin_bottom(24)
        self.sun_grid.set_hexpand(False)
        self.sun_grid.set_halign(Gtk.Align.CENTER)

        day_label_dummy = Gtk.Label()
        sizegroup = Gtk.SizeGroup(Gtk.SizeGroupMode.VERTICAL)
        sizegroup.add_widget(self.day_label)
        sizegroup.add_widget(day_label_dummy)

        expand_label1 = Gtk.Label()
        expand_label2 = Gtk.Label()
        expand_label1.set_vexpand(True)
        expand_label2.set_vexpand(True)

        grid = Gtk.Grid()
        grid.set_orientation(Gtk.Orientation.VERTICAL)
        grid.add(expand_label1)
        grid.add(day_label_dummy)
        grid.add(self.time_label)
        grid.add(self.day_label)
        grid.add(expand_label2)
        grid.add(self.sun_grid)

        self.add(grid)

        self.clock = None

    def set_clock(self, clock):
        self.clock = clock
        self.show_all()
        self.update()

    def update(self):
        if self.clock:
            timestr = self.clock.time_string
            daystr = self.clock.day_string
            self.time_label.set_markup(
                "<span size='72000' color='dimgray'><b>%s</b></span>" % timestr)
            self.day_label.set_markup(
                "<span size ='large' color='dimgray'><b>%s</b></span>" % daystr)
            if self.clock.sunrise_string and self.clock.sunset_string:
                self.sunrise_time_label.set_markup(
                    "<span size ='large'>%s</span>" % self.clock.sunrise_string)
                self.sunset_time_label.set_markup(
                    "<span size ='large'>%s</span>" % self.clock.sunset_string)
                self.sun_grid.show()
            else:
                self.sun_grid.hide()


class World(Clock):
    class Page:
        OVERVIEW = 0
        STANDALONE = 1

    def __init__(self, toolbar, embed):
        Clock.__init__(self, _("World"), toolbar, embed)

        self.settings = Gio.Settings(schema='org.gnome.clocks')

        # Translators: "New" refers to a world clock
        self.new_button = ToolButton(_("New"))
        self.new_button.connect('clicked', self._on_new_clicked)

        self.select_button = SymbolicToolButton("object-select-symbolic")
        self.select_button.connect('clicked', self._on_select_clicked)

        self.done_button = ToolButton(_("Done"))
        self.done_button.get_style_context().add_class('suggested-action')
        self.done_button.connect("clicked", self._on_done_clicked)

        self.back_button = SymbolicToolButton("go-previous-symbolic")
        self.back_button.connect('clicked', self._on_back_clicked)

        self.delete_button = Gtk.Button(_("Delete"))
        self.delete_button.connect('clicked', self._on_delete_clicked)

        f = os.path.join(Dirs.get_images_dir(), "day.png")
        self.daypixbuf = GdkPixbuf.Pixbuf.new_from_file(f)
        f = os.path.join(Dirs.get_images_dir(), "night.png")
        self.nightpixbuf = GdkPixbuf.Pixbuf.new_from_file(f)

        self.liststore = Gtk.ListStore(bool, str, object)
        self.iconview = SelectableIconView(self.liststore, 0, 1, self._thumb_data_func)
        self.iconview.connect("item-activated", self._on_item_activated)
        self.iconview.connect("selection-changed", self._on_selection_changed)

        contentview = ContentView(self.iconview,
                                  "document-open-recent-symbolic",
                                  _("Select <b>New</b> to add a world clock"))
        self.standalone = WorldStandalone()

        self.insert_page(contentview, World.Page.OVERVIEW)
        self.insert_page(self.standalone, World.Page.STANDALONE)
        self.set_current_page(World.Page.OVERVIEW)

        self._load()

        wallclock.connect("time-changed", self._tick_clocks)

    def _save(self):
        v = GLib.Variant('aa{sv}', [c.serialize() for c in self.clocks])
        self.settings.set_value('world-clocks', v)

    def _load(self):
        self.clocks = []
        # NOTE: we have to manually parse the variant because pygobject
        # automatically unpacks all the variant to native python objects
        # while we need to extract the variant object to pass to gweather
        locations = self.settings.get_value('world-clocks')
        for i in range(locations.n_children()):
            l = {}
            location_variant = locations.get_child_value(i)
            for j in range(location_variant.n_children()):
                v = location_variant.get_child_value(j)
                l[v.get_child_value(0).get_string()] = v.get_child_value(1).get_child_value(0)
            location = GWeather.Location.deserialize(gweather_world, l["location"])
            if location:
                self.clocks.append(ClockItem(location))

        for clock in self.clocks:
            self._add_clock_item(clock)
        self.select_button.set_sensitive(self.clocks)

    def _on_new_clicked(self, button):
        self.activate_new()

    def _on_select_clicked(self, button):
        self.iconview.set_selection_mode(True)
        self.update_toolbar()

    def _on_done_clicked(self, button):
        self.iconview.set_selection_mode(False)
        self.update_toolbar()
        self._embed.hide_floatingbar()

    def _on_back_clicked(self, button):
        self.change_page_spotlight(World.Page.OVERVIEW)

    def _on_delete_clicked(self, button):
        selection = self.iconview.get_selection()
        clocks = [self.liststore[path][2] for path in selection]
        self.delete_clocks(clocks)
        self.iconview.selection_deleted()

    def _thumb_data_func(self, view, cell, store, i, data):
        clock = store.get_value(i, 2)
        cell.text = clock.time_string
        cell.subtext = clock.day_string
        if clock.is_light:
            cell.props.pixbuf = self.daypixbuf
            cell.css_class = "light"
        else:
            cell.props.pixbuf = self.nightpixbuf
            cell.css_class = "dark"

    def _tick_clocks(self, *args):
        for c in self.clocks:
            c.tick()
        self.iconview.queue_draw()
        self.standalone.update()
        return True

    def _on_item_activated(self, iconview, path):
        clock = self.liststore[path][2]
        self.standalone.set_clock(clock)
        self.change_page_spotlight(World.Page.STANDALONE)

    def _on_selection_changed(self, iconview):
        selection = iconview.get_selection()
        n_selected = len(selection)
        self._toolbar.set_selection(n_selected)
        if n_selected > 0:
            self._embed.show_floatingbar(self.delete_button)
        else:
            self._embed.hide_floatingbar()

    def add_clock(self, location):
        if any(c.location.equal(location) for c in self.clocks):
            # duplicate
            return
        clock = ClockItem(location)
        self.clocks.append(clock)
        self._save()
        self._add_clock_item(clock)
        self.select_button.set_sensitive(True)
        self.show_all()

    def _add_clock_item(self, clock):
        label = GLib.markup_escape_text(clock.name)
        self.liststore.append([False, "<b>%s</b>" % label, clock])

    def delete_clocks(self, clocks):
        self.clocks = [c for c in self.clocks if c not in clocks]
        self._save()
        self.liststore.clear()
        self._load()

    def update_toolbar(self):
        self._toolbar.clear()
        if self.get_current_page() == World.Page.OVERVIEW:
            if self.iconview.selection_mode:
                self._toolbar.set_mode(Toolbar.Mode.SELECTION)
                self._toolbar.add_widget(self.done_button, Gtk.PackType.END)
            else:
                self._toolbar.set_mode(Toolbar.Mode.NORMAL)
                self._toolbar.add_widget(self.new_button)
                self._toolbar.add_widget(self.select_button, Gtk.PackType.END)
        elif self.get_current_page() == World.Page.STANDALONE:
            self._toolbar.set_mode(Toolbar.Mode.STANDALONE)
            self._toolbar.add_widget(self.back_button)
            self._toolbar.set_title(GLib.markup_escape_text(self.standalone.clock.name))

    def activate_new(self):
        window = NewWorldClockDialog(self.get_toplevel())
        window.connect("response", self._on_dialog_response)
        window.show_all()

    def _on_dialog_response(self, dialog, response):
        if response == 1:
            l = dialog.get_location()
            self.add_clock(l)
        dialog.destroy()
