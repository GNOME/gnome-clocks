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
import sys
from gettext import ngettext
from gi.repository import Gtk, Gdk, GObject, GLib, Gio, GtkClutter
from clocks import Clock
from world import World
from alarm import Alarm
from stopwatch import Stopwatch
from timer import Timer
from widgets import Embed
from utils import Dirs
from gnomeclocks import __version__, AUTHORS, COPYRIGHTS


class Window(Gtk.ApplicationWindow):
    def __init__(self, app):
        Gtk.ApplicationWindow.__init__(self, title=_("Clocks"),
                                       application=app,
                                       hide_titlebar_when_maximized=True)

        action = Gio.SimpleAction.new("new", None)
        action.connect("activate", self._on_new_activated)
        self.add_action(action)
        app.add_accelerator("<Primary>n", "win.new", None)

        action = Gio.SimpleAction.new("about", None)
        action.connect("activate", self._on_about_activated)
        self.add_action(action)

        css_provider = Gtk.CssProvider()
        css_provider.load_from_path(os.path.join(Dirs.get_data_dir(),
                                                 "gtk-style.css"))
        context = Gtk.StyleContext()
        context.add_provider_for_screen(Gdk.Screen.get_default(),
                                         css_provider,
                                         Gtk.STYLE_PROVIDER_PRIORITY_USER)


        self.set_size_request(640, 480)

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.add(vbox)

        self.notebook = Gtk.Notebook()
        self.notebook.set_show_tabs(False)
        self.notebook.set_show_border(False)
        self.notebook.show()

        self.embed = Embed(self.notebook)
        vbox.pack_end(self.embed, True, True, 0)

        self.world = World()
        self.alarm = Alarm()
        self.stopwatch = Stopwatch()
        self.timer = Timer()
        self.views = (self.world, self.alarm, self.stopwatch, self.timer)
        for view in self.views:
            self.notebook.append_page(view, None)

        self.toolbar = ClocksToolbar(self.views, self.embed)
        vbox.pack_start(self.toolbar, False, False, 0)

        self.world.connect("item-activated", self._on_item_activated)

        self.alarm.connect("item-activated", self._on_item_activated)
        self.alarm.connect("alarm-ringing", self._on_alarm_ringing)

        self.timer.connect("alarm-ringing", self._on_alarm_ringing)

        self.toolbar.connect("back-clicked", self._on_back_clicked)
        self.toolbar.connect("clock-changed", self._on_clock_changed)

        vbox.show()

    def _on_item_activated(self, view):
        def show_clock_standalone():
            view.set_mode(Clock.Mode.STANDALONE)
            self.toolbar.update_toolbar(view)

        self.embed.spotlight(show_clock_standalone)

    def _on_alarm_ringing(self, view):
        self.notebook.set_current_page(self.views.index(view))
        self.toolbar.update_toolbar(view)

    def _on_back_clicked(self, button, view):
        def show_clock_overview():
            view.set_mode(Clock.Mode.NORMAL)
            self.toolbar.update_toolbar(view)

        self.embed.spotlight(show_clock_overview)

    def _on_clock_changed(self, button, view):
        self.notebook.set_current_page(self.views.index(view))
        self.toolbar.update_toolbar(view)

    def _on_new_activated(self, action, param):
        view = self.views[self.notebook.get_current_page()]
        view.open_new_dialog()

    def _on_about_activated(self, action, param):
        about = Gtk.AboutDialog()
        about.set_title(_("About Clocks"))
        about.set_program_name(_("GNOME Clocks"))
        about.set_logo_icon_name("clocks")
        about.set_version(__version__)
        about.set_copyright(COPYRIGHTS)
        about.set_comments(
            _("Utilities to help you with the time."))
        about.set_authors(AUTHORS)
        about.set_translator_credits(_("translator-credits"))
        about.set_website("http://live.gnome.org/GnomeClocks")
        about.set_website_label(_("GNOME Clocks"))
        about.set_wrap_license("true")
        about.set_license_type(Gtk.License.GPL_2_0)
        about.set_license("GNOME Clocks is free software;"
            " you can redistribute it and/or modify it under the terms"
            " of the GNU General Public License as published by the"
            " Free Software Foundation; either version 2 of the"
            " License, or (at your option) any later version.\n"
            "  \n"
            "GNOME Clocks is distributed in the hope that it will be"
            " useful, but WITHOUT ANY WARRANTY; without even the"
            " implied warranty of MERCHANTABILITY or FITNESS FOR"
            " A PARTICULAR PURPOSE.  See the GNU General Public"
            " License for more details.\n"
            "  \n"
            "You should have received a copy of the GNU General"
            " Public License along with GNOME Clocks; if not, write"
            " to the Free Software Foundation, Inc., 51 Franklin"
            " Street, Fifth Floor, Boston, MA  02110-1301  USA\n")
        about.connect("response", lambda w, r: about.destroy())
        about.set_modal(True)
        about.set_transient_for(self)
        about.show()


class ClockButton(Gtk.RadioButton):
    _radio_group = None
    _size_group = None

    def __init__(self, text):
        Gtk.RadioButton.__init__(self, group=ClockButton._radio_group, draw_indicator=False)
        if not ClockButton._radio_group:
            ClockButton._radio_group = self
        if not ClockButton._size_group:
            ClockButton._size_group = Gtk.SizeGroup(mode=Gtk.SizeGroupMode.HORIZONTAL)
        # We use two labels to make sure they
        # keep the same size even when using bold
        self.label = Gtk.Label()
        self.label.set_markup(text)
        self.bold_label = Gtk.Label()
        self.bold_label.set_markup("<b>%s</b>" % text)
        ClockButton._size_group.add_widget(self.label)
        ClockButton._size_group.add_widget(self.bold_label)
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
            label.unset_state_flags (Gtk.StateFlags.ACTIVE)
            if self.get_active():
                self.add(self.bold_label)
            else:
                self.add(self.label)
            self.show_all()
        except TypeError:
            # at construction the is no label yet
            pass


class SymbolicButton(Gtk.Button):
    def __init__(self, iconname):
        Gtk.Button.__init__(self)
        icon = Gio.ThemedIcon.new_with_default_fallbacks(iconname)
        image = Gtk.Image()
        image.set_from_gicon(icon, Gtk.IconSize.MENU)
        self.add(image)
        self.set_size_request(34, 34)


class ClocksToolbar(Gtk.Toolbar):
    def __init__(self, views, embed):
        Gtk.Toolbar.__init__(self)

        self.get_style_context().add_class("clocks-toolbar")
        self.set_icon_size(Gtk.IconSize.MENU)
        self.get_style_context().add_class(Gtk.STYLE_CLASS_MENUBAR)

        self.views = views
        self.embed = embed

        size_group = Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL)

        left_item = Gtk.ToolItem()
        self.insert(left_item, -1)
        size_group.add_widget(left_item)

        left_box = Gtk.Box()
        left_item.add(left_box)

        self.new_button = Gtk.Button()
        self.new_button.set_action_name("win.new")
        self.new_button.set_size_request(64, 34)
        left_box.pack_start(self.new_button, False, False, 0)

        self.back_button = SymbolicButton("go-previous-symbolic")
        self.back_button.connect("clicked",
            lambda w: self.emit("back-clicked", self.current_view))
        left_box.pack_start(self.back_button, False, False, 0)

        center_item = Gtk.ToolItem()
        center_item.set_expand(True)
        self.insert(center_item, -1)

        center_box = Gtk.Box()
        center_item.add(center_box)

        self.button_box = Gtk.Box()
        self.button_box.set_homogeneous(True)
        self.button_box.set_halign(Gtk.Align.CENTER)
        self.button_box.get_style_context().add_class("linked")
        center_box.pack_start(self.button_box, True, False, 0)

        self.view_buttons = {}
        self.current_view = None
        for view in views:
            button = ClockButton(view.label)
            self.button_box.pack_start(button, True, True, 0)
            button.connect("toggled", self._on_toggled, view)
            self.view_buttons[view] = button
            if hasattr(view, "can_select"):
                view.connect("notify::can-select", self._on_can_select_changed)
            if view == views[0]:
                self.current_view = view
                button.set_active(True)

        self.title_label = Gtk.Label()
        self.title_label.set_halign(Gtk.Align.CENTER)
        self.title_label.set_valign(Gtk.Align.CENTER)
        center_box.pack_start(self.title_label, True, False, 0)

        right_item = Gtk.ToolItem()
        size_group.add_widget(right_item)

        right_box = Gtk.Box()
        right_item.add(right_box)
        self.insert(right_item, -1)

        self.select_button = SymbolicButton("object-select-symbolic")
        self.select_button.set_sensitive(self.current_view.can_select)
        self.select_button.connect('clicked', self._on_select_clicked)
        right_box.pack_end(self.select_button, False, False, 0)

        self.edit_button = Gtk.Button(_("Edit"))
        self.edit_button.set_size_request(64, 34)
        self.edit_button.connect('clicked', self._on_edit_clicked)
        right_box.pack_end(self.edit_button, False, False, 0)

        self.done_button = Gtk.Button(_("Done"))
        self.done_button.get_style_context().add_class('suggested-action')
        self.done_button.set_size_request(64, 34)
        self.done_button.connect("clicked", self._on_done_clicked)
        right_box.pack_end(self.done_button, False, False, 0)

        self.selection_handler = 0

        self.show_all()
        self.update_toolbar(self.current_view)

        self.embed._selectionToolbar._toolbarDelete.connect("clicked", self._on_delete_clicked)

    @GObject.Signal(arg_types=(Clock,))
    def back_clicked(self, view):
        self.select_button.set_sensitive(view.can_select)

    @GObject.Signal(arg_types=(Clock,))
    def clock_changed(self, view):
        self.current_view = view
        if hasattr(view, "can_select"):
            self.select_button.set_sensitive(view.can_select)

    def update_toolbar(self, view):
        if view is not self.current_view:
            self.view_buttons[view].set_active(True)
        if view.mode is Clock.Mode.NORMAL:
            self._show_normal_toolbar()
        elif view.mode is Clock.Mode.STANDALONE:
            self._show_standalone_toolbar()
        elif view.mode is Clock.Mode.SELECTION:
            self._show_selection_toolbar()

    def _show_normal_toolbar(self):
        self.get_style_context().remove_class("selection-mode")
        self.button_box.show()
        if self.current_view.new_label:
            self.new_button.set_label(self.current_view.new_label)
            self.new_button.show()
        else:
            self.new_button.hide()
        self.select_button.set_visible(hasattr(self.current_view, "can_select"))
        self.back_button.hide()
        self.title_label.hide()
        self.edit_button.hide()
        self.done_button.hide()
        if self.selection_handler:
            self.current_view.disconnect_by_func(self._on_selection_changed)
            self.selection_handler = 0

    def _show_standalone_toolbar(self):
        self.get_style_context().remove_class("selection-mode")
        self.button_box.hide()
        self.new_button.hide()
        self.select_button.hide()
        self.back_button.show_all()
        standalone = self.current_view.standalone
        self.title_label.set_markup("<b>%s</b>" % standalone.get_name())
        self.title_label.show()
        self.edit_button.set_visible(standalone.can_edit)
        self.done_button.hide()

    def _show_selection_toolbar(self):
        self.get_style_context().add_class("selection-mode")
        self.button_box.hide()
        self.new_button.hide()
        self.select_button.hide()
        self.back_button.hide()
        self._set_selection_label(0)
        self.title_label.show()
        self.edit_button.hide()
        self.done_button.show()
        self.selection_handler = \
             self.current_view.connect("selection-changed",
                                        self._on_selection_changed)

    def _on_toggled(self, widget, view):
        self.emit("clock-changed", view)

    def _set_selection_label(self, n):
        if n == 0:
            self.title_label.set_markup("(%s)" % _("Click on items to select them"))
        else:
            msg = ngettext("{0} item selected", "{0} items selected", n).format(n)
            self.title_label.set_markup("<b>%s</b>" % (msg))

    def _on_selection_changed(self, view):
        selection = view.get_selection()
        n_selected = len(selection)
        self._set_selection_label(n_selected)
        self.embed.set_show_selectionbar(n_selected > 0)

    def _on_can_select_changed(self, view, pspec):
        if view == self.current_view:
            self.select_button.set_sensitive(view.can_select)

    def _on_select_clicked(self, button):
        self.current_view.set_mode(Clock.Mode.SELECTION)
        self.update_toolbar(self.current_view)

    def _on_edit_clicked(self, button):
        standalone = self.current_view.standalone
        standalone.open_edit_dialog()

    def _on_done_clicked(self, widget):
        self.current_view.set_mode(Clock.Mode.NORMAL)
        self.update_toolbar(self.current_view)
        self.embed.set_show_selectionbar(False)

    def _on_delete_clicked(self, widget):
        self.current_view.delete_selected()
        self._set_selection_label(0)
        self.embed.set_show_selectionbar(False)


class ClocksApplication(Gtk.Application):
    def __init__(self):
        Gtk.Application.__init__(self)

    def do_activate(self):
        self.win = Window(self)
        self.win.present()

    def quit_cb(self, action, parameter):
        self.quit()

    def do_startup(self):
        Gtk.Application.do_startup(self)

        GtkClutter.init(sys.argv)

        action = Gio.SimpleAction.new("quit", None)
        action.connect("activate", self.quit_cb)
        self.add_action(action)

        menu = Gio.Menu()

        menu.append(_("About Clocks"), "win.about")

        quit = Gio.MenuItem()
        quit.set_attribute([("label", "s", _("Quit")),
                            ("action", "s", "app.quit"),
                            ("accel", "s", "<Primary>q")])
        menu.append_item(quit)

        self.set_app_menu(menu)
