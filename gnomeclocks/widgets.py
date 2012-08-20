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

from gi.repository import Gtk, Gdk, GdkPixbuf, GObject, Gio, Pango, PangoCairo
from gi.repository import GWeather

from storage import Location
from alarm import AlarmItem
from utils import Dirs, SystemSettings

import os
import cairo
import time


# FIXME: Use real sunrise/sunset time in the future
def get_is_day(hour):
    return (hour > 7 and hour < 19)


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

        self.label = Gtk.Label()
        self.label.set_markup(_("Search for a city: "))
        self.label.set_alignment(0.0, 0.5)

        world = GWeather.Location.new_world(True)
        self.searchEntry = GWeather.LocationEntry.new(world)
        self.find_gicon = Gio.ThemedIcon.new_with_default_fallbacks(
            'edit-find-symbolic')
        self.clear_gicon = Gio.ThemedIcon.new_with_default_fallbacks(
            'edit-clear-symbolic')
        self.searchEntry.set_icon_from_gicon(
            Gtk.EntryIconPosition.SECONDARY, self.find_gicon)
        self.searchEntry.set_activates_default(True)

        self.add_buttons(_("Cancel"), 0, _("Add"), 1)
        self.set_default_response(1)
        self.set_response_sensitive(1, False)

        box.pack_start(self.label, False, False, 6)
        box.pack_start(self.searchEntry, False, False, 3)
        box.set_border_width(5)

        self.searchEntry.connect("activate", self._set_city)
        self.searchEntry.connect("changed", self._set_city)
        self.searchEntry.connect("icon-release", self._icon_released)
        self.location = None
        self.show_all()

    def get_location(self):
        location = self.searchEntry.get_location()
        return Location(location)

    def _set_city(self, widget):
        location = self.searchEntry.get_location()
        if self.searchEntry.get_text() == '':
            self.searchEntry.set_icon_from_gicon(
                Gtk.EntryIconPosition.SECONDARY, self.find_gicon)
        else:
            self.searchEntry.set_icon_from_gicon(
                Gtk.EntryIconPosition.SECONDARY, self.clear_gicon)
        if location:
            self.set_response_sensitive(1, True)
        else:
            self.set_response_sensitive(1, False)

    def get_selection(self):
        return self.location

    def _icon_released(self, icon_pos, event, data):
        if self.searchEntry.get_icon_gicon(
            Gtk.EntryIconPosition.SECONDARY) == self.clear_gicon:
            self.searchEntry.set_text('')
            self.searchEntry.set_icon_from_gicon(
              Gtk.EntryIconPosition.SECONDARY, self.find_gicon)
            self.set_response_sensitive(1, False)


class DigitalClock():
    def __init__(self, location):
        self.location = location.location
        self.id = location.id
        self.timezone = self.location.get_timezone()
        self.offset = self.timezone.get_offset() * 60
        self.isDay = None
        self._last_time = None
        self.drawing = DigitalClockDrawing()
        self.standalone = DigitalClockStandalone(self.location)
        self.update()
        GObject.timeout_add(1000, self.update)

    def get_local_time(self):
        t = time.time() + time.timezone + self.offset
        t = time.localtime(t)
        return t

    def get_local_time_text(self):
        text = time.strftime("%I:%M%p", self.get_local_time())
        if text.startswith("0"):
            text = text[1:]
        return text

    def update(self):
        t = self.get_local_time_text()
        systemClockFormat = SystemSettings.get_clock_format()
        if systemClockFormat == '12h':
            t = time.strftime("%I:%M%p", self.get_local_time())
        else:
            t = time.strftime("%H:%M", self.get_local_time())
        if not t == self._last_time:
            local_time = self.get_local_time()
            isDay = get_is_day(local_time.tm_hour)
            if isDay:
                img = os.path.join(Dirs.get_image_dir(), "cities", "day.png")
            else:
                img = os.path.join(Dirs.get_image_dir(), "cities", "night.png")
            day = self.get_day()
            if day == "Today":
                self.drawing.render(t, img, isDay)
            else:
                self.drawing.render(t, img, isDay, day)
            self.standalone.update(img, t, systemClockFormat)
        self._last_time = t
        return True

    def get_pixbuf(self):
        return self.drawing.pixbuf

    def get_standalone_widget(self):
        return self.standalone

    def get_day(self):
        clock_time_day = self.get_local_time().tm_yday
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


class DigitalClockStandalone(Gtk.VBox):
    def __init__(self, location):
        Gtk.VBox.__init__(self, False)
        self.img = Gtk.Image()
        self.time_label = Gtk.Label()
        self.city_label = Gtk.Label()
        self.city_label.set_markup("<b>" + location.get_city_name() + "</b>")
        self.text = ""

        self.systemClockFormat = None

        self.connect("size-allocate", lambda x, y: self.update(None,
            self.text, self.systemClockFormat))

        #imagebox = Gtk.VBox()
        #imagebox.pack_start(self.img, False, False, 0)
        #imagebox.pack_start(self.city_label, False, False, 0)
        #imagebox.set_size_request(230, 230)

        self.timebox = timebox = Gtk.VBox()
        self.time_label.set_alignment(0.0, 0.5)
        timebox.pack_start(self.time_label, True, True, 0)

        self.hbox = hbox = Gtk.HBox()
        self.hbox.set_homogeneous(False)

        self.hbox.pack_start(Gtk.Label(), True, True, 0)
        # self.hbox.pack_start(imagebox, False, False, 0)
        # self.hbox.pack_start(Gtk.Label(), False, False, 30)
        self.hbox.pack_start(timebox, False, False, 0)
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

        sunbox = Gtk.VBox(True, 3)
        sunbox.pack_start(sunrise_hbox, False, False, 3)
        sunbox.pack_start(sunset_hbox, False, False, 3)

        hbox = Gtk.HBox()
        hbox.pack_start(Gtk.Label(), True, True, 0)
        hbox.pack_start(sunbox, False, False, 0)
        hbox.pack_start(Gtk.Label(), True, True, 0)
        self.pack_end(hbox, False, False, 30)

    def update(self, img, text, systemClockFormat):
        size = 72000  # FIXME: (self.get_allocation().height / 300) * 72000
        if img:
            pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_size(img, 500, 380)
            pixbuf = pixbuf.new_subpixbuf(0, 0, 208, 208)
            self.img.set_from_pixbuf(pixbuf)
        self.text = text
        self.time_label.set_markup(
            "<span size='%i' color='dimgray'><b>%s</b></span>" % (size, text))
        if systemClockFormat != self.systemClockFormat:
            sunrise_markup = ""
            sunset_markup = ""
            if systemClockFormat == "12h":
                sunrise_markup = sunrise_markup + "<span size ='large'>" +\
                    "7: 00 AM" + "</span>"
                sunset_markup = sunset_markup + "<span size ='large'>" +\
                    "7: 00 PM" + "</span>"
            else:
                sunrise_markup = sunrise_markup + "<span size ='large'>" +\
                    "07: 00" + "</span>"
                sunset_markup = sunset_markup + "<span size ='large'>" +\
                    "19: 00" + "</span>"
            self.sunrise_time_label.set_markup(sunrise_markup)
            self.sunset_time_label.set_markup(sunset_markup)
        self.systemClockFormat = systemClockFormat


class DigitalClockDrawing(Gtk.DrawingArea):
    width = 160
    height = 160

    def __init__(self):
        Gtk.DrawingArea.__init__(self)
        #self.set_size_request(width, height)

        self.pango_context = None
        self.ctx = None
        self.pixbuf = None
        self.surface = None
        self.show_all()

    def render(self, text, img, isDay, sub_text=None):
        self.surface = cairo.ImageSurface.create_from_png(img)
        ctx = cairo.Context(self.surface)
        ctx.scale(1.0, 1.0)
        ctx.set_source_surface(self.surface, 0, 0)
        ctx.paint()

        width = 136
        height = 72
        radius = 10
        degrees = 0.017453293

        x = (self.width - width) / 2
        y = (self.height - height) / 2

        # has to be before the drawing of the rectangle so the rectangle
        # takes the right size if we have subtexts
        self.pango_layout = self.create_pango_layout(text)
        self.pango_layout.set_markup(
            "<span size='xx-large'><b>%s</b></span>" % text, -1)
        if sub_text:
            self.pango_layout_subtext = self.create_pango_layout(sub_text)
            self.pango_layout_subtext.set_markup(
                "<span size='medium'>%s</span>" % sub_text, -1)
            self.pango_layout_subtext.set_width(width * Pango.SCALE)
            subtext_is_wrapped = self.pango_layout_subtext.is_wrapped()
            if subtext_is_wrapped:
                self.pango_layout_subtext.set_alignment(Pango.Alignment.CENTER)

        if not isDay:
            ctx.set_source_rgba(0.0, 0.0, 0.0, 0.7)
        else:
            ctx.set_source_rgba(1.0, 1.0, 1.0, 0.7)

        ctx.move_to(x, y)
        ctx.arc(x + width - radius, y + radius, radius, -90 * degrees,
                0 * degrees)
        if sub_text and subtext_is_wrapped:
            ctx.arc(x + width - radius, y + height - radius + 25, radius,
                    0 * degrees, 90 * degrees)
            ctx.arc(x + radius, y + height - radius + 25, radius,
                    90 * degrees, 180 * degrees)
        elif sub_text and not subtext_is_wrapped:
            ctx.arc(x + width - radius, y + height - radius + 10, radius,
                    0 * degrees, 90 * degrees)
            ctx.arc(x + radius, y + height - radius + 10, radius,
                    90 * degrees, 180 * degrees)
        else:
            ctx.arc(x + width - radius, y + height - radius, radius,
                    0 * degrees, 90 * degrees)
            ctx.arc(x + radius, y + height - radius, radius,
                    90 * degrees, 180 * degrees)
        ctx.arc(x + radius, y + radius, radius, 180 * degrees, 270 * degrees)
        ctx.close_path()
        ctx.fill()

        if not isDay:
            ctx.set_source_rgb(1.0, 1.0, 1.0)
        else:
            ctx.set_source_rgb(0.0, 0.0, 0.0)

        text_width, text_height = self.pango_layout.get_pixel_size()
        ctx.move_to(x + (width - text_width) / 2,
                    y + (height - text_height) / 2)
        PangoCairo.show_layout(ctx, self.pango_layout)

        if sub_text:
            sub_text_width, sub_text_height =\
                self.pango_layout_subtext.get_pixel_size()
            # centered on x axis, 5 pixels below main text on y axis
            # for some reason setting the alignment adds an extra frame
            # around it, slight change to allow for this
            if subtext_is_wrapped:
                ctx.move_to(x + (width - sub_text_width) / 2 - 10,
                            y + (height - text_height) / 2 +
                            sub_text_height - 10)
            else:
                ctx.move_to(x + (width - sub_text_width) / 2,
                            y + (height - text_height) / 2 +
                            sub_text_height + 10)
            PangoCairo.show_layout(ctx, self.pango_layout_subtext)

        pixbuf = Gdk.pixbuf_get_from_surface(self.surface, 0, 0, self.width,
                                             self.height)
        self.pixbuf = pixbuf
        return self.pixbuf


class AlarmWidget():
    def __init__(self, time_given, repeat):
        self.drawing = DigitalClockDrawing()
        t = time_given
        isDay = get_is_day(int(t[:2]))
        if isDay:
            img = os.path.join(Dirs.get_image_dir(), "cities", "day.png")
        else:
            img = os.path.join(Dirs.get_image_dir(), "cities", "night.png")
        self.drawing.render(t, img, isDay, repeat)

    def get_pixbuf(self):
        return self.drawing.pixbuf


class AlarmDialog(Gtk.Dialog):
    def __init__(self, alarm_view, parent, vevent=None):
        if vevent:
            Gtk.Dialog.__init__(self, _("Edit Alarm"), parent)
        else:
            Gtk.Dialog.__init__(self, _("New Alarm"), parent)
        self.set_border_width(6)
        self.parent = parent
        self.set_transient_for(parent)
        self.set_modal(True)
        self.day_buttons = []

        content_area = self.get_content_area()
        self.add_buttons(_("Cancel"), 0, _("Save"), 1)

        self.cf = SystemSettings.get_clock_format()
        grid = Gtk.Grid()
        grid.set_row_spacing(9)
        grid.set_column_spacing(6)
        grid.set_border_width(6)
        content_area.pack_start(grid, True, True, 0)

        if vevent:
            t = vevent.dtstart.value
            h = int(t.strftime("%I"))
            m = int(t.strftime("%m"))
            p = t.strftime("%p")
            name = vevent.summary.value
            repeat = self.get_repeat_days_from_vevent(vevent)
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
        self.minuteselect.connect('output', self.show_leading_zeros)
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
            if btn.get_label()[:2]  in repeat:
                btn.set_active(True)
            box.pack_start(btn, True, True, 0)
            self.day_buttons.append(btn)
        grid.attach(box, 1, 2, gridcols - 1, 1)

    def show_leading_zeros(self, spin_button):
        spin_button.set_text('{: 02d}'.format(spin_button.get_value_as_int()))
        return True

    def get_repeat_days_from_vevent(self, vevent):
        rrule = vevent.rrule.value
        repeat = []
        if rrule[5] == 'W':
            days = rrule[18:]
            repeat = days.split(",")
        return repeat

    def get_alarm_item(self):
        name = self.entry.get_text()
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
        repeat = []
        for btn in self.day_buttons:
            if btn.get_active():
                repeat.append(btn.get_label()[:2])
        return AlarmItem(name, repeat, h, m, p)


class EmptyPlaceholder(Gtk.Box):
    def __init__(self, icon, message):
        Gtk.Box.__init__(self)
        self.set_orientation(Gtk.Orientation.VERTICAL)
        gicon = Gio.ThemedIcon.new_with_default_fallbacks(icon)
        image = Gtk.Image.new_from_gicon(gicon, Gtk.IconSize.DIALOG)
        image.set_sensitive(False)
        text = Gtk.Label()
        text.get_style_context().add_class("dim-label")
        text.set_markup(message)
        self.pack_start(Gtk.Label(), True, True, 0)
        self.pack_start(image, False, False, 6)
        self.pack_start(text, False, False, 6)
        self.pack_start(Gtk.Label(), True, True, 0)
        self.show_all()


# Python version of the gd-toggle-pixbuf-renderer of gnome-documents
# we should use those widgets directly at some point, but for now
# it is easier to just reimplement this renderer than include and build
# a C library
class TogglePixbufRenderer(Gtk.CellRendererPixbuf):

    __gproperties__ = {
         "active" : (GObject.TYPE_BOOLEAN,
                    "Active",
                    "Whether the cell renderer is active",
                    False,
                    GObject.PARAM_READWRITE),
         "toggle-visible" : (GObject.TYPE_BOOLEAN,
                             "Toggle visible",
                             "Whether to draw the toggle indicator",
                             False,
                             GObject.PARAM_READWRITE)
    }

    def __init__(self):
        Gtk.CellRendererPixbuf.__init__(self)
        self._active = False
        self._toggle_visible = False

    def do_render(self, cr, widget, background_area, cell_area, flags):
        Gtk.CellRendererPixbuf.do_render(self, cr, widget, background_area, cell_area, flags)

        if not self._toggle_visible:
            return

        xpad, ypad = self.get_padding()
        direction = widget.get_direction()

        # FIXME: currently broken with g-i
        # icon_size = widget.style_get_property("check-icon-size")
        icon_size = 40

        if direction == Gtk.TextDirection.RTL:
            x_offset = xpad;
        else:
            x_offset = cell_area.width - icon_size - xpad

        check_x = cell_area.x + x_offset
        check_y = cell_area.y + cell_area.height - icon_size - ypad

        context = widget.get_style_context()
        context.save()
        context.add_class(Gtk.STYLE_CLASS_CHECK)

        if self._active:
            context.set_state(Gtk.StateFlags.ACTIVE)

        Gtk.render_check(context, cr, check_x, check_y, icon_size, icon_size)

        context.restore()

    def do_get_size(self, widget, cell_area):

        # FIXME: currently broken with g-i
        # icon_size = widget.style_get_property("check-icon-size")
        icon_size = 40

        x_offset, y_offset, width, height = Gtk.CellRendererPixbuf.do_get_size(self, widget, cell_area)

        width += icon_size / 4

        return (x_offset, y_offset, width, height)

    def do_get_property(self, prop):
        if prop.name == "active":
            return self._active
        elif prop.name == "toggle-visible":
            return self._toggle_visible
        else:
            raise AttributeError, 'unknown property %s' % prop.name

    def do_set_property(self, prop, value):
        if prop.name == "active":
            self._active = value
        elif prop.name == "toggle-visible":
            self._toggle_visible = value
        else:
            raise AttributeError, 'unknown property %s' % prop.name


class SelectableIconView(Gtk.IconView):
    def __init__(self, model, selection_col, pixbuf_col, text_col = None):
        Gtk.IconView.__init__(self, model)

        self.selection_mode = False

        self.selection_col = selection_col

        self.renderer_pixbuf = TogglePixbufRenderer();
        self.renderer_pixbuf.set_alignment(0.5, 0.5)
        self.pack_start(self.renderer_pixbuf, False)
        self.add_attribute(self.renderer_pixbuf, "active", selection_col)
        self.add_attribute(self.renderer_pixbuf, "pixbuf", pixbuf_col)

        if text_col:
            renderer_text = Gtk.CellRendererText()
            renderer_text.set_alignment(0.5, 0.5)
            self.pack_start(renderer_text, True)
            self.add_attribute(renderer_text, "markup", text_col)

    def set_selection_mode(self, active):
        self.selection_mode = active
        self.renderer_pixbuf.set_property("toggle_visible", active)

    # FIXME: override both button press and release to check
    # that a specfic item is clicked? see libgd...
    def do_button_press_event (self, event):
        path = self.get_path_at_pos(event.x, event.y);

        if path:
            if self.selection_mode:
                i = self.get_model().get_iter(path)
                if i:
                    selected = self.get_model().get_value(i, self.selection_col)
                    self.get_model().set_value(i, self.selection_col, not selected)
                    self.emit("selection-changed")
            else:
                self.emit("item-activated", path)

        return False

