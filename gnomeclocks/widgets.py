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

import cairo
from gi.repository import GObject, Gio, Gtk, Gdk, Pango, PangoCairo
from gi.repository import Clutter, GtkClutter


class DigitalClockDrawing(Gtk.DrawingArea):
    width = 160
    height = 160

    def __init__(self):
        Gtk.DrawingArea.__init__(self)
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


class Spinner(Gtk.SpinButton):
    def __init__(self, min_value, max_value):
        super(Spinner, self).__init__()
        self.set_orientation(Gtk.Orientation.VERTICAL)
        self.set_numeric(True)
        self.set_increments(1.0, 1.0)
        self.set_wrap(True)
        self.set_range(min_value, max_value)
        attrs = Pango.parse_markup('<span font_desc=\"64.0\">00</span>', -1, u'\x00')[1]
        self.set_attributes(attrs)

        self.connect('output', self._show_leading_zeros)

    def _show_leading_zeros(self, spin_button):
        spin_button.set_text('{:02d}'.format(spin_button.get_value_as_int()))
        return True


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
    active = GObject.Property(type=bool, default=False)
    toggle_visible = GObject.Property(type=bool, default=False)

    def __init__(self):
        Gtk.CellRendererPixbuf.__init__(self)

    def do_render(self, cr, widget, background_area, cell_area, flags):
        Gtk.CellRendererPixbuf.do_render(self, cr, widget, background_area, cell_area, flags)

        if not self.toggle_visible:
            return

        xpad, ypad = self.get_padding()
        direction = widget.get_direction()

        # FIXME: currently broken with g-i
        # icon_size = widget.style_get_property("check-icon-size")
        icon_size = 40

        if direction == Gtk.TextDirection.RTL:
            x_offset = xpad
        else:
            x_offset = cell_area.width - icon_size - xpad

        check_x = cell_area.x + x_offset
        check_y = cell_area.y + cell_area.height - icon_size - ypad

        context = widget.get_style_context()
        context.save()
        context.add_class(Gtk.STYLE_CLASS_CHECK)

        if self.active:
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


class SelectableIconView(Gtk.IconView):
    def __init__(self, model, selection_col, pixbuf_col, text_col):
        Gtk.IconView.__init__(self, model)

        self.selection_mode = False

        self.selection_col = selection_col

        self.set_spacing(3)
        self.get_style_context().add_class('content-view')

        self.renderer_pixbuf = TogglePixbufRenderer()
        self.renderer_pixbuf.set_alignment(0.5, 0.5)
        self.pack_start(self.renderer_pixbuf, False)
        self.add_attribute(self.renderer_pixbuf, "active", selection_col)
        self.add_attribute(self.renderer_pixbuf, "pixbuf", pixbuf_col)

        renderer_text = Gtk.CellRendererText()
        renderer_text.set_alignment(0.5, 0.5)
        self.pack_start(renderer_text, True)
        self.add_attribute(renderer_text, "markup", text_col)

    def get_selection(self):
        selection = []
        store = self.get_model()
        for i in store:
            selected = store.get_value(i.iter, self.selection_col)
            if selected:
                selection.append(i.path)
        return selection

    def set_selection_mode(self, active):
        if self.selection_mode != active:
            self.selection_mode = active
            self.renderer_pixbuf.set_property("toggle_visible", active)

            # force redraw
            self.queue_draw()

    # FIXME: override both button press and release to check
    # that a specfic item is clicked? see libgd...
    def do_button_press_event(self, event):
        path = self.get_path_at_pos(event.x, event.y)

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


class ContentView(Gtk.Box):
    def __init__(self, iconview, icon, emptymsg):
        Gtk.Box.__init__(self)
        self.iconview = iconview
        self.scrolledwindow = Gtk.ScrolledWindow()
        self.scrolledwindow.add(self.iconview)
        self.emptypage = EmptyPlaceholder(icon, emptymsg)
        self.pack_start(self.emptypage, True, True, 0)

        model = self.iconview.get_model()
        model.connect("row-inserted", self._on_item_inserted)
        model.connect("row-deleted", self._on_item_deleted)

    def _on_item_inserted(self, model, path, treeiter):
        self._update_empty_view(model)

    def _on_item_deleted(self, model, path):
        self._update_empty_view(model)

    def _update_empty_view(self, model):
        if len(model) == 0:
            if self.scrolledwindow in self.get_children():
                self.remove(self.scrolledwindow)
                self.pack_start(self.emptypage, True, True, 0)
        else:
            if self.emptypage in self.get_children():
                self.remove(self.emptypage)
                self.pack_start(self.scrolledwindow, True, True, 0)
        self.show_all()


class SelectionToolbar():
    DEFAULT_WIDTH = 300

    def __init__(self, parent_actor):
        self.widget = Gtk.Toolbar()
        self.widget.set_show_arrow(False)
        self.widget.set_icon_size(Gtk.IconSize.LARGE_TOOLBAR)
        self.widget.get_style_context().add_class('osd')
        self.widget.set_size_request(SelectionToolbar.DEFAULT_WIDTH, -1)

        self.actor = GtkClutter.Actor.new_with_contents(self.widget)
        self.actor.set_opacity(0)
        self.actor.get_widget().override_background_color(0, Gdk.RGBA(0, 0, 0, 0))

        constraint = Clutter.AlignConstraint()
        constraint.set_source(parent_actor)
        constraint.set_align_axis(Clutter.AlignAxis.X_AXIS)
        constraint.set_factor(0.50)
        self.actor.add_constraint(constraint)

        constraint = Clutter.AlignConstraint()
        constraint.set_source(parent_actor)
        constraint.set_align_axis(Clutter.AlignAxis.Y_AXIS)
        constraint.set_factor(0.95)
        self.actor.add_constraint(constraint)

        self._leftBox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        self._leftGroup = Gtk.ToolItem()
        self._leftGroup.set_expand(True)
        self._leftGroup.add(self._leftBox)
        self.widget.insert(self._leftGroup, -1)
        self._toolbarDelete = Gtk.Button(_("Delete"))
        self._leftBox.pack_start(self._toolbarDelete, True, True, 0)
        self.widget.show_all()

    def fade_in(self):
        self.actor.save_easing_state()
        self.actor.set_easing_duration(300)
        self.actor.set_easing_mode(Clutter.AnimationMode.EASE_OUT_QUAD)
        self.actor.set_opacity(255)
        self.actor.restore_easing_state()

    def fade_out(self):
        self.actor.save_easing_state()
        self.actor.set_easing_duration(300)
        self.actor.set_easing_mode(Clutter.AnimationMode.EASE_OUT_QUAD)
        self.actor.set_opacity(0)
        self.actor.restore_easing_state()


class Embed(GtkClutter.Embed):
    def __init__(self, notebook):
        GtkClutter.Embed.__init__(self)
        self.set_use_layout_size(True)

        self.stage = self.get_stage()

        self._overlayLayout = Clutter.BinLayout()
        self.actor = Clutter.Box()
        self.actor.set_layout_manager(self._overlayLayout)
        constraint = Clutter.BindConstraint()
        constraint.set_source(self.stage)
        constraint.set_coordinate(Clutter.BindCoordinate.SIZE)
        self.actor.add_constraint(constraint)
        self.stage.add_actor(self.actor)

        self._contentsLayout = Clutter.BoxLayout()
        self._contentsLayout.set_vertical(True)
        self._contentsActor = Clutter.Box()
        self._contentsActor.set_layout_manager(self._contentsLayout)
        self._overlayLayout.add(self._contentsActor,
            Clutter.BinAlignment.FILL, Clutter.BinAlignment.FILL)

        self._viewLayout = Clutter.BinLayout()
        self._viewActor = Clutter.Box()
        self._viewActor.set_layout_manager(self._viewLayout)
        self._contentsLayout.set_expand(self._viewActor, True)
        self._contentsLayout.set_fill(self._viewActor, True, True)
        self._contentsActor.add_actor(self._viewActor)

        self._notebook = notebook
        self._notebookActor = GtkClutter.Actor.new_with_contents(self._notebook)
        self._viewLayout.add(self._notebookActor,
                             Clutter.BinAlignment.FILL,
                             Clutter.BinAlignment.FILL)

        self._selectionToolbar = SelectionToolbar(self._contentsActor)
        self._overlayLayout.add(self._selectionToolbar.actor,
                                Clutter.BinAlignment.FIXED,
                                Clutter.BinAlignment.FIXED)
        self.show_all()

        # also pack a white background to use for spotlights
        # between window modes
        white = Clutter.Color.get_static(Clutter.StaticColor.WHITE)
        self._background = Clutter.Actor(background_color=white)
        self._viewLayout.add(self._background,
                             Clutter.BinAlignment.FILL,
                             Clutter.BinAlignment.FILL)
        self._background.lower_bottom()

    def _spotlight_finished(self, actor, name, is_finished):
        self._viewActor.set_child_below_sibling(self._background, None)
        self._background.disconnect_by_func(self._spotlight_finished)

    def spotlight(self, action):
        self._background.save_easing_state()
        self._background.set_easing_duration(0)
        self._viewActor.set_child_above_sibling(self._background, None)
        self._background.set_opacity(255)
        self._background.restore_easing_state()

        action()

        self._background.save_easing_state()
        self._background.set_easing_duration(200)
        self._background.set_easing_mode(Clutter.AnimationMode.LINEAR)
        self._background.set_opacity(0)
        self._background.restore_easing_state()
        self._background.connect('transition-stopped::opacity', self._spotlight_finished)

    def set_show_selectionbar(self, show):
        if show:
            self._selectionToolbar.fade_in()
        else:
            self._selectionToolbar.fade_out()
