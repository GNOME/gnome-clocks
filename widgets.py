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

from gi.repository import Gtk, GObject, Gio, PangoCairo, Pango, GWeather
from gi.repository import Gdk, GdkPixbuf
import cairo, time

class NewWorldClockWidget (Gtk.Box):

    __gsignals__ = {'add-clock': (GObject.SignalFlags.RUN_LAST,
                    None, (GObject.TYPE_PYOBJECT,))}

    def __init__ (self):
        Gtk.Box.__init__(self)
        self.set_border_width (9)
        self.set_size_request(400,-1)
        box = Gtk.Box(orientation = Gtk.Orientation.VERTICAL)
        box.set_spacing(9)
        self.pack_start(Gtk.Label(), True, True, 0)
        self.pack_start(box, True, True, 9)
        self.pack_start(Gtk.Label(), True, True, 0)
        
        self.label = Gtk.Label()
        self.label.set_markup("Search for a city or a time zone...")
        self.label.set_alignment(0.0, 0.5)
        
        world = GWeather.Location.new_world(True)
        self.searchEntry = GWeather.LocationEntry.new(world)
        #self.searchEntry.set_placeholder_text("Search for a city or a time zone...")
        
        header = Gtk.Label("Add New Clock")
        header.set_markup("<span size='x-large'><b>Add New Clock</b></span>")
        
        btnBox = Gtk.Box()
        
        self.addBtn = Gtk.Button()
        label = Gtk.Label ("Add")
        label.set_padding(6, 0)
        self.addBtn.add(label)
        #self.addBtn.get_style_context ().add_class ("clocks-continue");
        
        self.addBtn.set_sensitive(False)
        
        self.cancelBtn = Gtk.Button()
        label = Gtk.Label ("Cancel")
        label.set_padding(6, 0)
        self.cancelBtn.add(label)
        
        btnBox.set_size_request (-1, 33)
        btnBox.set_spacing(9)
        btnBox.pack_end(self.addBtn, False, False, 0)
        btnBox.pack_end(self.cancelBtn, False, False, 0)
        
        box.pack_start(header, True, True, 0)
        box.pack_start(Gtk.Label(), True, True, 3)
        box.pack_start(self.label, False, False, 0)
        box.pack_start(self.searchEntry, False, False, 9)
        box.pack_start(btnBox, True, True, 0)
        
        self.searchEntry.connect("activate", self._set_city)
        self.searchEntry.connect("changed", self._set_city)
        self.addBtn.connect("clicked", self._add_clock)
        self.location = None
        self.show_all ()
        
    def _set_city (self, widget):
        location = widget.get_location()
        if location:
            self.addBtn.set_sensitive(True)
        else:
            self.addBtn.set_sensitive(False)
    
    def _add_clock(self, widget):
        location = self.searchEntry.get_location()
        self.emit("add-clock", location)
    
    def reset(self):
        self.searchEntry.set_text("")
    
    def get_selection (self):
        return self.location

class DigitalClock ():
    def __init__(self, location):
        self.location = location
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

    def get_image(self):
        local_time = self.get_local_time ()
        if local_time.tm_hour > 7 and local_time.tm_hour < 19:
            return "data/cities/day.png"
        else:
            return "data/cities/night.png"

    def get_is_day(self):
        local_time = self.get_local_time ()
        if local_time.tm_hour > 7 and local_time.tm_hour < 19:
            return True
        else:
            return False

    def update(self):
        t = self.get_local_time_text ()
        if not t == self._last_time:
            img = self.get_image ()
            self.drawing.render(t, img, self.get_is_day ())
            if self.view_iter and self.list_store:
                self.list_store.set_value(self.view_iter, 0, self.drawing.pixbuf)
            self.standalone.update (img, t)
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

        box = Gtk.VBox ()
        box.pack_start (self.img, False, False, 3)
        box.pack_start (self.city_label, False, False, 3)

        hbox = Gtk.HBox ()
        hbox.pack_start (Gtk.Label (), True, True, 0)
        hbox.pack_start (box, False, False, 16)
        hbox.pack_start (Gtk.Label (), True, True, 0)
        hbox.pack_start (self.time_label, False, False, 16)
        hbox.pack_start (Gtk.Label (), True, True, 0)
        self.pack_start (Gtk.Label (), True, True, 3)
        self.pack_start (hbox, True, True, 0)
        self.pack_start (Gtk.Label (), True, True, 6)

    def update (self, img, text):
        pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_size (img, 500, 380)
        pixbuf = pixbuf.new_subpixbuf(0 , 0 , 208, 208)
        self.img.set_from_pixbuf (pixbuf)
        self.time_label.set_markup ("<span size='72000'><b>%s</b></span>" %(text,))


class DigitalClockDrawing (Gtk.DrawingArea):
    width = 160
    height = 160

    def __init__(self):
        Gtk.DrawingArea.__init__(self)
        self.set_size_request(160,160)
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

        ctx.arc(x + width - radius, y + radius, radius, -90 * degrees, 0 * degrees);
        ctx.arc(x + width - radius, y + height - radius, radius, 0 * degrees, 90 * degrees);
        ctx.arc(x + radius, y + height - radius, radius, 90 * degrees, 180 * degrees);
        ctx.arc(x + radius, y + radius, radius, 180 * degrees, 270 * degrees);
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

"""
if text.startswith("0"):
    text = text[1:]


def get_image(self, local_time):
    if local_time.tm_hour > 7 and local_time.tm_hour < 19:
        return "data/cities/day.png"
    else:
        return "data/cities/night.png"
"""
