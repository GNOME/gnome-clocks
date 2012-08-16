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

from gi.repository import Gtk, Gdk, GdkPixbuf, GObject, Gio, PangoCairo, Pango, GWeather

from storage import Location
from alarm import AlarmItem
from utils import Dirs

import os
import cairo, time


class NewWorldClockDialog (Gtk.Dialog):

    __gsignals__ = {'add-clock': (GObject.SignalFlags.RUN_LAST,
                    None, (GObject.TYPE_PYOBJECT,))}

    def __init__ (self, parent):
        Gtk.Dialog.__init__(self, _("Add New Clock"), parent)
        self.set_transient_for(parent)
        self.set_modal(True)
        self.set_border_width (9)
        self.set_size_request(400,-1)
        box = Gtk.Box(orientation = Gtk.Orientation.VERTICAL)
        box.set_spacing(3)
        area = self.get_content_area()
        area.pack_start(box, True, True, 9)

        self.label = Gtk.Label()
        self.label.set_markup(_("Search for a city:"))
        self.label.set_alignment(0.0, 0.5)

        world = GWeather.Location.new_world(True)
        self.searchEntry = GWeather.LocationEntry.new(world)
        self.find_gicon = Gio.ThemedIcon.new_with_default_fallbacks('edit-find-symbolic')
        self.clear_gicon = Gio.ThemedIcon.new_with_default_fallbacks('edit-clear-symbolic')
        self.searchEntry.set_icon_from_gicon(Gtk.EntryIconPosition.SECONDARY, self.find_gicon)
        #self.searchEntry.set_can_focus(False)

        header = Gtk.Label(_("Add New Clock"))
        header.set_markup("<span size='medium'><b>%s</b></span>" % (_("Add a New World Clock")))

        btnBox = Gtk.Box()

        self.add_buttons(_("Cancel"), 0, _("Add"), 1)
        widget = self.get_widget_for_response (1)
        widget.set_sensitive (False)

        box.pack_start(header, True, True, 0)
        box.pack_start(Gtk.Label(), True, True, 3)
        box.pack_start(self.label, False, False, 0)
        box.pack_start(self.searchEntry, False, False, 9)

        self.searchEntry.connect("activate", self._set_city)
        self.searchEntry.connect("changed", self._set_city)
        self.searchEntry.connect("icon-release", self._icon_released)
        self.connect("response", self._on_response_clicked)
        self.location = None
        self.show_all ()

    def _on_response_clicked (self, widget, response_id):
        if response_id == 1:
            location = self.searchEntry.get_location()
            location = Location (location)
            self.emit("add-clock", location)
        self.destroy ()

    def _set_city (self, widget):
        location = self.searchEntry.get_location()
        widget = self.get_widget_for_response (1)
        if self.searchEntry.get_text () == '':
            self.searchEntry.set_icon_from_gicon(Gtk.EntryIconPosition.SECONDARY, self.find_gicon)
        else:
            self.searchEntry.set_icon_from_gicon(Gtk.EntryIconPosition.SECONDARY, self.clear_gicon)
        if location:
            widget.set_sensitive(True)
        else:
            widget.set_sensitive(False)

    def get_selection (self):
        return self.location

    def _icon_released(self, icon_pos, event, data):
        if self.searchEntry.get_icon_gicon(Gtk.EntryIconPosition.SECONDARY) == self.clear_gicon:
            self.searchEntry.set_text('')
            self.searchEntry.set_icon_from_gicon(Gtk.EntryIconPosition.SECONDARY, self.find_gicon)
            widget = self.get_widget_for_response (1)
            widget.set_sensitive(False)

class DigitalClock ():
    def __init__(self, location):
        self.location = location.location
        self.id = location.id
        self.timezone = self.location.get_timezone()
        self.offset = self.timezone.get_offset() * 60
        self.isDay = None
        self._last_time = None

        self.view_iter = None
        self.list_store = None

        self.drawing = DigitalClockDrawing ()
        self.standalone = DigitalClockStandalone (self.location)
        self.update ()
        GObject.timeout_add(1000, self.update)

    def get_local_time (self):
        t = time.time() + time.timezone + self.offset
        t = time.localtime(t)
        return t

    def get_local_time_text (self):
        text = time.strftime("%I:%M %p", self.get_local_time ())
        if text.startswith("0"):
            text = text[1:]
        return text

    def get_system_clock_format(self):
        settings = Gio.Settings.new('org.gnome.desktop.interface')
        systemClockFormat = settings.get_string('clock-format')
        return systemClockFormat

    def get_image(self):
        local_time = self.get_local_time ()
        if local_time.tm_hour > 7 and local_time.tm_hour < 19:
            return os.path.join (Dirs.get_image_dir (), "cities", "day.png")
        else:
            return os.path.join (Dirs.get_image_dir (), "cities", "night.png")

    def get_is_day(self):
        local_time = self.get_local_time ()
        if local_time.tm_hour > 7 and local_time.tm_hour < 19:
            return True
        else:
            return False

    def update(self):
        t = self.get_local_time_text ()
        systemClockFormat = self.get_system_clock_format ()
        if systemClockFormat == '12h':
            t = time.strftime("%I:%M %p", self.get_local_time ())
        else:
            t = time.strftime("%H:%M", self.get_local_time ()) #Convert to 24h
        if not t == self._last_time:
            img = self.get_image ()
            self.drawing.render(t, img, self.get_is_day ())
            if self.view_iter and self.list_store:
                self.list_store.set_value(self.view_iter, 0, self.drawing.pixbuf)
            self.standalone.update (img, t, systemClockFormat)
        self._last_time = t
        return True

    def set_iter (self, list_store, view_iter):
        self.view_iter = view_iter
        self.list_store = list_store

    def get_standalone_widget (self):
        return self.standalone

class DigitalClockStandalone (Gtk.VBox):
    def __init__ (self, location):
        Gtk.VBox.__init__ (self, False)
        self.img = Gtk.Image ()
        self.time_label = Gtk.Label ()
        self.city_label = Gtk.Label ()
        self.city_label.set_markup ("<b>"+location.get_city_name()+"</b>")
        self.text = ""

        self.systemClockFormat = None

        self.connect ("size-allocate", lambda x, y: self.update (None, self.text, self.systemClockFormat))

        #imagebox = Gtk.VBox ()
        #imagebox.pack_start (self.img, False, False, 0)
        #imagebox.pack_start (self.city_label, False, False, 0)
        #imagebox.set_size_request (230, 230)

        self.timebox = timebox = Gtk.VBox ()
        self.time_label.set_alignment (0.0, 0.5)
        timebox.pack_start (self.time_label, True, True, 0)

        self.hbox = hbox = Gtk.HBox ()
        self.hbox.set_homogeneous (False)

        self.hbox.pack_start (Gtk.Label(), True, True, 0)
        # self.hbox.pack_start (imagebox, False, False, 0)
        # self.hbox.pack_start (Gtk.Label (), False, False, 30)
        self.hbox.pack_start (timebox, False, False, 0)
        self.hbox.pack_start (Gtk.Label(), True, True, 0)

        self.pack_start (Gtk.Label (), True, True, 25)
        self.pack_start (hbox, False, False, 0)
        self.pack_start (Gtk.Label (), True, True, 0)

        sunrise_label = Gtk.Label ()
        sunrise_label.set_markup ("<span size ='large' color='dimgray'> Sunrise </span>")
        self.sunrise_time_label = Gtk.Label ()
        sunrise_label.set_alignment (1.0, 0.5)
        self.sunrise_time_label.set_alignment (0.0, 0.5)
        sunrise_hbox = Gtk.Box (True, 9)
        sunrise_hbox.pack_start (sunrise_label, False, False, 0)
        sunrise_hbox.pack_start (self.sunrise_time_label, False, False, 0)

        sunset_label = Gtk.Label ()
        sunset_label.set_markup ("<span size ='large' color='dimgray'> Sunset </span>")
        sunset_label.set_alignment (1.0, 0.5)
        self.sunset_time_label = Gtk.Label ()
        self.sunset_time_label.set_alignment (0.0, 0.5)
        sunset_hbox = Gtk.Box (True, 9)
        sunset_hbox.pack_start (sunset_label, False, False, 0)
        sunset_hbox.pack_start (self.sunset_time_label, False, False, 0)

        sunbox = Gtk.VBox (True, 3)
        sunbox.pack_start (sunrise_hbox, False, False, 3)
        sunbox.pack_start (sunset_hbox, False, False, 3)

        hbox = Gtk.HBox ()
        hbox.pack_start (Gtk.Label (), True, True, 0)
        hbox.pack_start (sunbox, False, False, 0)
        hbox.pack_start (Gtk.Label (), True, True, 0)
        self.pack_end (hbox, False, False, 30)

    def update (self, img, text, systemClockFormat):
        size = 72000 #(self.get_allocation ().height / 300) * 72000
        if img:
            pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_size (img, 500, 380)
            pixbuf = pixbuf.new_subpixbuf(0 , 0 , 208, 208)
            self.img.set_from_pixbuf (pixbuf)
        self.text = text
        self.time_label.set_markup ("<span size='%i' color='dimgray'><b>%s</b></span>" %(size, text))
        if systemClockFormat != self.systemClockFormat:
            sunrise_markup = ""
            sunset_markup = ""
            if systemClockFormat == "12h":
                sunrise_markup = sunrise_markup + "<span size ='large'>" + "7:00 AM" + "</span>"
                sunset_markup = sunset_markup + "<span size ='large'>" + "7:00 PM" + "</span>"
            else:
                sunrise_markup = sunrise_markup + "<span size ='large'>" + "07:00" + "</span>"
                sunset_markup = sunset_markup + "<span size ='large'>" + "19:00" + "</span>"
            self.sunrise_time_label.set_markup (sunrise_markup)
            self.sunset_time_label.set_markup (sunset_markup)
        self.systemClockFormat = systemClockFormat

class DigitalClockDrawing (Gtk.DrawingArea):
    width = 160
    height = 160

    def __init__(self):
        Gtk.DrawingArea.__init__(self)
        #self.set_size_request(width,height)

        self.pango_context = None
        self.ctx = None
        self.pixbuf = None
        self.surface = None
        self.show_all()

    def render(self, text, img, isDay):
        print "updating"
        self.surface = cairo.ImageSurface.create_from_png(img)
        ctx = cairo.Context(self.surface)
        ctx.scale(1.0, 1.0)
        ctx.set_source_surface(self.surface, 0, 0)
        ctx.paint()

        width = 136
        height = 72
        radius = 10
        degrees = 0.017453293

        x = (self.width - width)/2
        y = (self.height - height)/2

        if not isDay:
            ctx.set_source_rgba(0.0, 0.0, 0.0, 0.7)
        else:
            ctx.set_source_rgba(1.0, 1.0, 1.0, 0.7)

        ctx.arc(x + width - radius, y + radius, radius, -90 * degrees, 0 * degrees)
        ctx.arc(x + width - radius, y + height - radius, radius, 0 * degrees, 90 * degrees)
        ctx.arc(x + radius, y + height - radius, radius, 90 * degrees, 180 * degrees)
        ctx.arc(x + radius, y + radius, radius, 180 * degrees, 270 * degrees)
        ctx.close_path()
        ctx.fill()

        self.pango_layout = self.create_pango_layout(text)
        self.pango_layout.set_markup ("<span size='xx-large'><b>%s</b></span>"%text, -1)

        if not isDay:
            ctx.set_source_rgb(1.0, 1.0, 1.0)
        else:
            ctx.set_source_rgb(0.0, 0.0, 0.0)

        text_width, text_height = self.pango_layout.get_pixel_size()
        ctx.move_to(x + (width - text_width)/2, y + (height - text_height)/2)
        PangoCairo.show_layout(ctx, self.pango_layout)

        pixbuf = Gdk.pixbuf_get_from_surface(self.surface, 0, 0, self.width, self.height)
        self.pixbuf = pixbuf
        return self.pixbuf

class AlarmWidget():
    def __init__(self, time_given):
        self.drawing = DigitalClockDrawing ()
        clockformat = self.get_system_clock_format()
        t = time_given
        isDay = self.get_is_day(t)
        if isDay == True:
            img = os.path.join (Dirs.get_image_dir (), "cities", "day.png")
        else:
            img = os.path.join (Dirs.get_image_dir (), "cities", "night.png")
        self.drawing.render(t, img, isDay)

    def get_system_clock_format(self):
        settings = Gio.Settings.new('org.gnome.desktop.interface')
        systemClockFormat = settings.get_string('clock-format')
        return systemClockFormat

    def get_is_day(self, t):
        if t[6:8] == 'AM':
            return True
        else:
            return False

    def set_iter (self, list_store, view_iter):
        self.view_iter = view_iter
        self.list_store = list_store

class NewAlarmDialog (Gtk.Dialog):

    __gsignals__ = {'add-alarm': (GObject.SignalFlags.RUN_LAST,
                    None, (GObject.TYPE_PYOBJECT,))}

    def __init__(self, parent):
        Gtk.Dialog.__init__(self, _("New Alarm"), parent)
        self.set_border_width (12)
        self.parent = parent
        self.set_transient_for(parent)
        self.set_modal(True)
        self.repeat_days = []

        self.cf = cf = self.get_system_clock_format()
        if cf == "12h":
            table1 = Gtk.Table(4, 6, False)
        else:
            table1 = Gtk.Table(4, 5, False)
        table1.set_row_spacings(9)
        table1.set_col_spacings(9)
        content_area = self.get_content_area ()
        content_area.pack_start(table1, True, True, 0)
        self.add_buttons(_("Cancel"), 0, _("Save"), 1)
        self.connect("response", self.on_response)
        table1.set_border_width (5)

        t = time.localtime()
        h = t.tm_hour
        m = t.tm_min
        p = time.strftime("%p", t)
        time_label = Gtk.Label (_("Time"))
        time_label.set_alignment(1.0, 0.5)
        points = Gtk.Label (":")
        points.set_alignment(0.5, 0.5)

        if cf == "12h":
            if p == "PM":
                h = h-12
            self.hourselect = hourselect = AlarmDialogSpin(h, 1, 12)
        else:
            self.hourselect = hourselect = AlarmDialogSpin(h, 0, 23)
        self.minuteselect = minuteselect = AlarmDialogSpin(m, 0, 59)



        if cf == "12h":
            self.ampm = ampm = Gtk.ComboBoxText()
            ampm.append_text("AM")
            ampm.append_text("PM")
            if p == 'AM':
                ampm.set_active(0)
            else:
                ampm.set_active(1)

            table1.attach (time_label, 0, 1, 0, 1)
            table1.attach (hourselect, 1, 2, 0, 1)
            table1.attach (points, 2, 3, 0, 1)
            table1.attach (minuteselect, 3, 4, 0, 1)
            table1.attach (ampm, 4, 5, 0, 1)
        else:
            table1.attach (time_label, 0, 1, 0, 1)
            table1.attach (hourselect, 1, 2, 0, 1)
            table1.attach (points, 2, 3, 0, 1)
            table1.attach (minuteselect, 3, 4, 0, 1)

        name = Gtk.Label(_("Name"))
        name.set_alignment(1.0, 0.5)
        repeat = Gtk.Label(_("Repeat Every"))
        repeat.set_alignment(1.0, 0.5)
        sound = Gtk.Label(_("Sound"))
        sound.set_alignment(1.0, 0.5)

        table1.attach(name, 0, 1, 1, 2)
        table1.attach(repeat, 0, 1, 2, 3)
        #table1.attach(sound, 0, 1, 3, 4)

        self.entry = entry = Gtk.Entry ()
        entry.set_text(_("New Alarm"))
        entry.set_editable (True)
        if cf == "12h":
            table1.attach(entry, 1, 5, 1, 2)
        else:
            table1.attach(entry, 1, 4, 1, 2)

        buttond1 = Gtk.ToggleButton(label=_("Mon"))
        buttond1.connect("clicked", self.on_d1_clicked)
        buttond2 = Gtk.ToggleButton(label=_("Tue"))
        buttond2.connect("clicked", self.on_d2_clicked)
        buttond3 = Gtk.ToggleButton(label=_("Wed"))
        buttond3.connect("clicked", self.on_d3_clicked)
        buttond4 = Gtk.ToggleButton(label=_("Thu"))
        buttond4.connect("clicked", self.on_d4_clicked)
        buttond5 = Gtk.ToggleButton(label=_("Fri"))
        buttond5.connect("clicked", self.on_d5_clicked)
        buttond6 = Gtk.ToggleButton(label=_("Sat"))
        buttond6.connect("clicked", self.on_d6_clicked)
        buttond7 = Gtk.ToggleButton(label=_("Sun"))
        buttond7.connect("clicked", self.on_d7_clicked)

        # create a box and put them all in it
        box = Gtk.Box (True, 0)
        box.get_style_context().add_class("linked")
        box.pack_start (buttond1, True, True, 0)
        box.pack_start (buttond2, True, True, 0)
        box.pack_start (buttond3, True, True, 0)
        box.pack_start (buttond4, True, True, 0)
        box.pack_start (buttond5, True, True, 0)
        box.pack_start (buttond6, True, True, 0)
        box.pack_start (buttond7, True, True, 0)
        if cf == "12h":
            table1.attach(box, 1, 5, 2, 3)
        else:
            table1.attach(box, 1, 4, 2, 3)

        soundbox = Gtk.ComboBox ()
        #table1.attach(soundbox, 1, 3, 3, 4)

    def get_system_clock_format(self):
        settings = Gio.Settings.new('org.gnome.desktop.interface')
        systemClockFormat = settings.get_string('clock-format')
        return systemClockFormat

    def on_response(self, widget, id):
        if id == 0:
            self.destroy ()
        if id == 1:
            name = self.entry.get_text()  #Perfect
            repeat = self.repeat_days
            h = self.hourselect.get_value_as_int()
            m = self.minuteselect.get_value_as_int()
            if self.cf == "12h":
                r = self.ampm.get_active()
                if r == 0:
                    p = "AM"
                else:
                    p = "PM"
            else:
                p = None
            new_alarm = AlarmItem(name, repeat, h, m, p)
            self.emit('add-alarm', new_alarm)
            self.destroy ()
        else:
            pass


    def on_d1_clicked(self, btn):
        if btn.get_active() == True:
            self.repeat_days.append('MO')
        if btn.get_active() == False:
            self.repeat_days.remove('MO')

    def on_d2_clicked(self, btn):
        if btn.get_active() == True:
            self.repeat_days.append('TU')
        else:
            self.repeat_days.remove('TU')

    def on_d3_clicked(self, btn):
        if btn.get_active() == True:
            self.repeat_days.append('WE')
        else:
            self.repeat_days.remove('WE')

    def on_d4_clicked(self, btn):
        if btn.get_active() == True:
            self.repeat_days.append('TH')
        else:
            self.repeat_days.remove('TH')

    def on_d5_clicked(self, btn):
        if btn.get_active() == True:
            self.repeat_days.append('FR')
        else:
            self.repeat_days.remove('FR')

    def on_d6_clicked(self, btn):
        if btn.get_active() == True:
            self.repeat_days.append('SA')
        else:
            self.repeat_days.remove('SA')

    def on_d7_clicked(self, btn):
        if btn.get_active() == True:
            self.repeat_days.append('SU')
        else:
            self.repeat_days.remove('SU')

class AlarmDialogSpin(Gtk.Box):
    def __init__(self, value, min_num, max_num):
        Gtk.Box.__init__(self)
        self.get_style_context().add_class('linked')
        self.max_num = max_num
        self.min_num = min_num
        #
        group = Gtk.SizeGroup()
        group.set_mode(Gtk.SizeGroupMode.VERTICAL)
        self.entry = entry = Gtk.Entry()
        entry.set_size_request(-1, -1)
        self.entry.set_text(str(value))
        self.entry.set_max_length(2)
        self.entry.set_alignment(1)
        height = self.entry.get_allocated_height()

        group.add_widget(entry)
        #
        m_gicon = Gio.ThemedIcon.new_with_default_fallbacks("list-remove-symbolic")
        m_img = Gtk.Image.new_from_gicon(m_gicon, Gtk.IconSize.MENU)
        minus = Gtk.Button()
      #  minus.set_size_request(-1, 10)
        minus.set_image(m_img)
        minus.connect("clicked", self._on_click_minus)
        group.add_widget(minus)
        #
        p_gicon = Gio.ThemedIcon.new_with_default_fallbacks("list-add-symbolic")
        p_img = Gtk.Image.new_from_gicon(p_gicon, Gtk.IconSize.MENU)
        plus = Gtk.Button()
        #plus.set_size_request(-1, 10)
        plus.set_image(p_img)
        plus.connect("clicked", self._on_click_plus)
        group.add_widget(plus)
        #
        self.pack_start(entry, False, False, 0)
        self.pack_start(minus, False, False, 0)
        self.pack_start(plus, False, False, 0)
        self.show_all()

    def get_value_as_int(self):
        text = self.entry.get_text()
        return int(text)

    def _on_click_minus(self, btn):
        value = self.get_value_as_int()
        if value == self.min_num:
            new_value = self.max_num
        else:
            new_value = value - 1
        self.entry.set_text(str(new_value))

    def _on_click_plus(self, btn):
        value = self.get_value_as_int()
        if value == self.max_num:
            new_value = self.min_num
        else:
            new_value = value + 1
        self.entry.set_text(str(new_value))

class WorldEmpty(Gtk.Box):
    def __init__(self):
        Gtk.Box.__init__(self)
        self.set_orientation(Gtk.Orientation.VERTICAL)
        gicon = Gio.ThemedIcon.new_with_default_fallbacks("document-open-recent-symbolic")
        image = Gtk.Image.new_from_gicon(gicon, Gtk.IconSize.DIALOG)
        image.set_sensitive (False)
        text = Gtk.Label("")
        text.set_markup("<span color='darkgrey'>" + _("Select <b>New</b> to add a world clock") + "</span>")
        self.pack_start(Gtk.Label(""), True, True, 0)
        self.pack_start(image, False, False, 6)
        self.pack_start(text, False, False, 6)
        self.pack_start(Gtk.Label(""), True, True, 0)
        self.button = Gtk.ToggleButton()
        self.show_all()

    def unselect_all(self):
        pass

class AlarmsEmpty(Gtk.Box):
    def __init__(self):
        Gtk.Box.__init__(self)
        self.set_orientation(Gtk.Orientation.VERTICAL)
        gicon = Gio.ThemedIcon.new_with_default_fallbacks("document-open-recent-symbolic")
        image = Gtk.Image.new_from_gicon(gicon, Gtk.IconSize.DIALOG)
        image.set_sensitive (False)
        text = Gtk.Label("")
        text.set_markup("<span color='darkgrey'>" + _("Select <b>New</b> to add a world clock") + "</span>")
        self.pack_start(Gtk.Label(""), True, True, 0)
        self.pack_start(image, False, False, 6)
        self.pack_start(text, False, False, 6)
        self.pack_start(Gtk.Label(""), True, True, 0)
        self.button = Gtk.ToggleButton()
        self.show_all()

    def unselect_all(self):
        pass
