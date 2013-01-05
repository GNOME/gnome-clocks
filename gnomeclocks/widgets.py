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

from gettext import ngettext
from gi.repository import GObject, Gio, Gtk, Gdk, Pango
from gi.repository import Clutter, GtkClutter


class PageButton(Gtk.RadioButton):
    _radio_group = None
    _size_group = None

    def __init__(self, text, page):
        Gtk.RadioButton.__init__(self, group=PageButton._radio_group, draw_indicator=False)
        if not PageButton._radio_group:
            PageButton._radio_group = self
        if not PageButton._size_group:
            PageButton._size_group = Gtk.SizeGroup(mode=Gtk.SizeGroupMode.HORIZONTAL)
        self.page = page
        # We use two labels to make sure they
        # keep the same size even when using bold
        self.label = Gtk.Label()
        self.label.set_markup(text)
        self.label.show()
        self.bold_label = Gtk.Label()
        self.bold_label.set_markup("<b>%s</b>" % text)
        self.bold_label.show()
        PageButton._size_group.add_widget(self.label)
        PageButton._size_group.add_widget(self.bold_label)
        if self.get_active():
            self.add(self.bold_label)
        else:
            self.add(self.label)
        self.set_alignment(0.5, 0.5)
        self.set_size_request(100, 34)
        self.get_style_context().add_class('linked')

    def do_toggled(self):
        try:
            label = self.get_child()
            self.remove(label)
            # We need to unset the flag manually until GTK fixes
            # https://bugzilla.gnome.org/show_bug.cgi?id=688519
            label.unset_state_flags(Gtk.StateFlags.ACTIVE)
            if self.get_active():
                self.add(self.bold_label)
            else:
                self.add(self.label)
            self.show_all()
        except TypeError:
            # at construction the is no label yet
            pass


class Toolbar(Gtk.Toolbar):
    class Mode:
        NORMAL = 0
        SELECTION = 1
        STANDALONE = 2

    def __init__(self):
        Gtk.Toolbar.__init__(self)

        self.mode = Toolbar.Mode.NORMAL
        self.n_pages = 0
        self.cur_page = 0

        self.get_style_context().add_class("clocks-toolbar")
        self.set_icon_size(Gtk.IconSize.MENU)
        self.get_style_context().add_class(Gtk.STYLE_CLASS_MENUBAR)

        size_group = Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL)

        left_item = Gtk.ToolItem()
        size_group.add_widget(left_item)
        self.left_box = Gtk.Box()
        left_item.add(self.left_box)
        self.insert(left_item, -1)

        center_item = Gtk.ToolItem()
        center_item.set_expand(True)
        self.center_box = Gtk.Box()
        center_item.add(self.center_box)
        self.insert(center_item, -1)

        right_item = Gtk.ToolItem()
        size_group.add_widget(right_item)
        self.right_box = Gtk.Box()
        right_item.add(self.right_box)
        self.insert(right_item, -1)

        self.pages_box = Gtk.Box()
        self.pages_box.set_homogeneous(True)
        self.pages_box.set_halign(Gtk.Align.CENTER)
        self.pages_box.get_style_context().add_class("linked")
        self.center_box.pack_start(self.pages_box, True, False, 0)

        self.selection_label = Gtk.Label()
        self.selection_label.set_halign(Gtk.Align.CENTER)
        self.selection_label.set_valign(Gtk.Align.CENTER)
        self.center_box.pack_start(self.selection_label, True, False, 0)
        self.set_selection(0)

        self.title_label = Gtk.Label()
        self.title_label.set_halign(Gtk.Align.CENTER)
        self.title_label.set_valign(Gtk.Align.CENTER)
        self.center_box.pack_start(self.title_label, True, False, 0)

        self.show_all()

    def append_page(self, label):
        button = PageButton(label, self.n_pages)
        button.show()
        self.pages_box.pack_start(button, True, True, 0)
        button.connect("toggled", lambda b: self.set_page(b.page))
        if self.n_pages == 0:
            button.set_active(True)
        self.n_pages += 1

    def set_page(self, page):
        if page != self.cur_page:
            self.cur_page = page
            self.emit("page-changed", page)

    def add_widget(self, widget, pack=Gtk.PackType.START):
        if pack == Gtk.PackType.START:
            self.left_box.pack_start(widget, False, False, 0)
        else:
            self.right_box.pack_end(widget, False, False, 0)
        widget.show()

    def clear(self):
        for w in self.left_box:
            self.left_box.remove(w)
        for w in self.right_box:
            self.right_box.remove(w)

    def set_mode(self, mode):
        if mode is Toolbar.Mode.NORMAL:
            self.get_style_context().remove_class("selection-mode")
            self.pages_box.show()
            self.selection_label.hide()
            self.title_label.hide()
        elif mode is Toolbar.Mode.SELECTION:
            self.get_style_context().add_class("selection-mode")
            self.pages_box.hide()
            self.selection_label.show()
            self.title_label.hide()
        elif mode is Toolbar.Mode.STANDALONE:
            self.get_style_context().remove_class("selection-mode")
            self.pages_box.hide()
            self.selection_label.hide()
            self.title_label.show()

    def set_selection(self, n):
        if n == 0:
            self.selection_label.set_markup("(%s)" % _("Click on items to select them"))
        else:
            msg = ngettext("{0} item selected", "{0} items selected", n).format(n)
            self.selection_label.set_markup("<b>%s</b>" % (msg))

    def set_title(self, title):
        self.title_label.set_markup("<b>%s</b>" % title)

    @GObject.Signal(arg_types=(int,))
    def page_changed(self, page):
        self.current_page = page


class ToolButton(Gtk.Button):
    def __init__(self, label):
        Gtk.Button.__init__(self, label)
        self.set_size_request(64, 34)


class SymbolicToolButton(Gtk.Button):
    def __init__(self, iconname):
        Gtk.Button.__init__(self)
        icon = Gio.ThemedIcon.new_with_default_fallbacks(iconname)
        image = Gtk.Image()
        image.set_from_gicon(icon, Gtk.IconSize.MENU)
        image.show()
        self.add(image)
        self.set_size_request(34, 34)


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


class DigitalClockRenderer(Gtk.CellRendererPixbuf):
    css_class = GObject.Property(type=str)
    text = GObject.Property(type=str)
    subtext = GObject.Property(type=str)
    active = GObject.Property(type=bool, default=False)
    toggle_visible = GObject.Property(type=bool, default=False)

    def __init__(self, **kwds):
        Gtk.CellRendererPixbuf.__init__(self, **kwds)

        # FIXME: currently broken with g-i
        # icon_size = widget.style_get_property("check-icon-size")
        self.icon_size = 40

    def do_render(self, cr, widget, background_area, cell_area, flags):
        context = widget.get_style_context()

        context.save()
        context.add_class("clocks-digital-renderer")
        context.add_class(self.css_class)

        cr.save()
        Gdk.cairo_rectangle(cr, cell_area)
        cr.clip()

        # draw background
        if self.props.pixbuf:
            Gtk.CellRendererPixbuf.do_render(self, cr, widget, background_area, cell_area, flags)
        else:
            Gtk.render_frame(context, cr, cell_area.x, cell_area.y, cell_area.width, cell_area.height)
            Gtk.render_background(context, cr, cell_area.x, cell_area.y, cell_area.width, cell_area.height)

        cr.translate(cell_area.x, cell_area.y)

        # for now the space around the digital clock is hardcoded and
        # relative to the image width (not the width of the cell which
        # may be larger in case of long city names).
        # We need to know the width to create the pango layouts
        if self.props.pixbuf:
            pixbuf_margin = (cell_area.width - self.props.pixbuf.get_width()) // 2
        else:
            pixbuf_margin = 0
        margin = 12 + pixbuf_margin
        padding = 12
        w = cell_area.width - 2 * margin

        # create the layouts so that we can measure them
        layout = widget.create_pango_layout("")
        layout.set_markup(
            "<span size='xx-large'><b>%s</b></span>" % self.text, -1)
        layout.set_width(w * Pango.SCALE)
        layout.set_alignment(Pango.Alignment.CENTER)
        text_w, text_h = layout.get_pixel_size()

        if self.subtext:
            layout_subtext = widget.create_pango_layout("")
            layout_subtext.set_markup(
                "<span size='medium'>%s</span>" % self.subtext, -1)
            layout_subtext.set_width(w * Pango.SCALE)
            layout_subtext.set_alignment(Pango.Alignment.CENTER)
            subtext_w, subtext_h = layout_subtext.get_pixel_size()
            subtext_pad = 6
            # We just assume the first line is the longest
            line = layout_subtext.get_line(0)
            ink_rect, log_rect = line.get_pixel_extents()
            subtext_w = log_rect.width
        else:
            subtext_w, subtext_h, subtext_pad = 0, 0, 0

        # measure the actual height and coordinates (xpad is ignored for now)
        h = 2 * padding + text_h + subtext_h + subtext_pad
        x = margin
        y = (cell_area.height - h) / 2

        context.add_class("inner")

        # draw inner rectangle background
        Gtk.render_frame(context, cr, x, y, w, h)
        Gtk.render_background(context, cr, x, y, w, h)

        # draw text
        Gtk.render_layout(context, cr, x, y + padding, layout)
        if self.subtext:
            Gtk.render_layout(context, cr, x, y + padding + text_h + subtext_pad,
                              layout_subtext)

        context.restore()

        # draw the overlayed checkbox
        if self.toggle_visible:
            context.save()
            context.add_class(Gtk.STYLE_CLASS_CHECK)

            xpad, ypad = self.get_padding()
            direction = widget.get_direction()
            if direction == Gtk.TextDirection.RTL:
                x_offset = xpad
            else:
                x_offset = cell_area.width - self.icon_size - xpad

            check_x = x_offset
            check_y = cell_area.height - self.icon_size - ypad

            if self.active:
                context.set_state(Gtk.StateFlags.ACTIVE)

            Gtk.render_check(context, cr, check_x, check_y, self.icon_size, self.icon_size)

            context.restore()

        cr.restore()

    def do_get_size(self, widget, cell_area):
        x_offset, y_offset, width, height = Gtk.CellRendererPixbuf.do_get_size(self, widget, cell_area)
        width += self.icon_size // 4
        height += self.icon_size // 4
        return (x_offset, y_offset, width, height)


class SelectableIconView(Gtk.IconView):
    def __init__(self, model, selection_col, text_col, thumb_data_func):
        Gtk.IconView.__init__(self, model)

        self.selection_mode = False
        self.selection_col = selection_col

        self.get_style_context().add_class('content-view')

        self.set_column_spacing(20)
        self.set_margin(16)

        self.icon_renderer = DigitalClockRenderer()
        self.icon_renderer.set_alignment(0.5, 0.5)
        self.icon_renderer.set_fixed_size(160, 160)
        self.pack_start(self.icon_renderer, False)
        self.add_attribute(self.icon_renderer, "active", selection_col)
        self.set_cell_data_func(self.icon_renderer, thumb_data_func, None)

        renderer_text = Gtk.CellRendererText()
        renderer_text.set_alignment(0.5, 0.5)
        renderer_text.set_fixed_size(160, -1)
        renderer_text.props.wrap_width = 140
        renderer_text.props.wrap_mode = Pango.WrapMode.WORD_CHAR
        self.pack_start(renderer_text, True)
        self.add_attribute(renderer_text, "markup", text_col)

    def get_selection(self):
        store = self.get_model()
        return [row.path for row in store if row[self.selection_col]]

    def selection_deleted(self):
        # IconView is not very smart and does not emit selection-changed
        # if selected items are deleted, so we give it a push ourselves...
        self.emit("selection-changed")

    def set_selection_mode(self, active):
        if self.selection_mode != active:
            # clear selection
            if not active:
                self.unselect_all()
                store = self.get_model()
                for row in store:
                    row[self.selection_col] = False

            self.selection_mode = active
            self.icon_renderer.set_property("toggle-visible", active)

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


class FloatingToolbar:
    DEFAULT_WIDTH = 300

    def __init__(self, parent_actor):
        self.widget = Gtk.Toolbar()
        self.widget.set_show_arrow(False)
        self.widget.set_icon_size(Gtk.IconSize.LARGE_TOOLBAR)
        self.widget.get_style_context().add_class('osd')
        self.widget.set_size_request(FloatingToolbar.DEFAULT_WIDTH, -1)

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

        self.button_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        item = Gtk.ToolItem()
        item.set_expand(True)
        item.add(self.button_box)
        self.widget.insert(item, -1)

        self.widget.show_all()
        self.actor.hide()

        self._transition = None

    def add_widget(self, widget):
        widget.show()
        self.button_box.pack_start(widget, True, True, 0)

    def clear(self):
        for w in self.button_box:
            self.button_box.remove(w)

    def fade_in(self):
        self.actor.show()
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
        if not self._transition:
            self._transition = self.actor.get_transition("opacity")
            self._transition.connect("completed", self._on_transition_completed)

    def _on_transition_completed(self, transition):
        if self.actor.get_opacity() == 0:
            self.actor.hide()
        self._transition = None


class Embed(GtkClutter.Embed):
    def __init__(self, notebook):
        GtkClutter.Embed.__init__(self)
        self.set_use_layout_size(True)

        # Set can-focus to false and override key-press and
        # key-release so that we skip all Clutter key event
        # handling and we let the contained gtk widget do
        # their thing
        # See https://bugzilla.gnome.org/show_bug.cgi?id=684988
        self.set_can_focus(False)

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
                                Clutter.BinAlignment.FILL,
                                Clutter.BinAlignment.FILL)

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

        self._floatingToolbar = FloatingToolbar(self._contentsActor)
        self._overlayLayout.add(self._floatingToolbar.actor,
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

    def do_key_press_event(self, event):
        return False

    def do_key_release_event(self, event):
        return False

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

    def show_floatingbar(self, widget):
        self._floatingToolbar.clear()
        self._floatingToolbar.add_widget(widget)
        self._floatingToolbar.fade_in()

    def hide_floatingbar(self):
        self._floatingToolbar.fade_out()
