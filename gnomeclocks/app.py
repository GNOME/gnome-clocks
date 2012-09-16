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
        self.vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.embed = Embed(self.vbox)
        self.add(self.embed)
        self.notebook = Gtk.Notebook()
        self.notebook.set_show_tabs(False)
        self.notebook.set_show_border(False)

        self.world = World()
        self.alarm = Alarm()
        self.stopwatch = Stopwatch()
        self.timer = Timer()

        self.views = (self.world, self.alarm, self.stopwatch, self.timer)

        self.toolbar = ClocksToolbar(self.views, self.embed)

        self.vbox.pack_start(self.toolbar, False, False, 0)

        self.single_evbox = Gtk.EventBox()

        self.vbox.pack_end(self.notebook, True, True, 0)
        for view in self.views:
            self.notebook.append_page(view, None)
        self.notebook.append_page(self.single_evbox, None)

        self.world.connect("show-standalone", self._on_show_standalone)
        self.alarm.connect("show-standalone", self._on_show_standalone)

        self.toolbar.connect("view-clock", self._on_view_clock)
        self.vbox.show_all()
        self.show_all()
        self.toolbar.show_overview_toolbar()

    def show_clock(self, view):
        self.toolbar.activate_view(view)

    def _on_show_standalone(self, widget, d):
        def show_standalone_page():
            widget = d.get_standalone_widget()
            self.toolbar.show_standalone_toolbar(widget)
            self.single_evbox.add(widget)
            self.notebook.set_current_page(-1)

        if self.notebook.get_current_page() != len(self.views):
            self.embed.spotlight(show_standalone_page)

    def _on_view_clock(self, button, view):
        def show_clock_view():
            for child in self.single_evbox.get_children():
                self.single_evbox.remove(child)
            view.unselect_all()
            self.notebook.set_current_page(self.views.index(view))
            self.toolbar.show_overview_toolbar()

        if self.single_evbox.get_children():
            self.embed.spotlight(show_clock_view)
        else:
            show_clock_view()

    def _on_new_activated(self, action, param):
        self.toolbar.current_view.open_new_dialog()

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
    _group = None

    def __init__(self, text):
        Gtk.RadioButton.__init__(self, group=ClockButton._group, draw_indicator=False)
        self.text = text
        self.label = Gtk.Label()
        self.label.set_markup(text)
        self.add(self.label)
        self.set_alignment(0.5, 0.5)
        self.set_size_request(100, 34)
        self.get_style_context().add_class('linked')
        if not ClockButton._group:
            ClockButton._group = self

    def do_toggled(self):
        try:
            if self.get_active():
                self.label.set_markup("<b>%s</b>" % self.text)
            else:
                self.label.set_markup("%s" % self.text)
        except AttributeError:
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

        sizeGroup = Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL)

        leftItem = Gtk.ToolItem()
        self.insert(leftItem, -1)
        sizeGroup.add_widget(leftItem)

        leftBox = Gtk.Box()
        leftItem.add(leftBox)

        # Translators: "New" refers to a world clock or an alarm
        self.newButton = Gtk.Button(_("New"))
        self.newButton.set_action_name("win.new")
        self.newButton.set_size_request(64, 34)
        leftBox.pack_start(self.newButton, False, False, 0)

        self.backButton = SymbolicButton("go-previous-symbolic")
        self.backButton.connect("clicked",
            lambda w: self.emit("view-clock", self.current_view))
        leftBox.pack_start(self.backButton, False, False, 0)

        centerItem = Gtk.ToolItem()
        centerItem.set_expand(True)
        self.insert(centerItem, -1)

        centerBox = Gtk.Box()
        centerItem.add(centerBox)

        self.buttonBox = Gtk.Box()
        self.buttonBox.set_homogeneous(True)
        self.buttonBox.set_halign(Gtk.Align.CENTER)
        self.buttonBox.get_style_context().add_class("linked")
        centerBox.pack_start(self.buttonBox, True, False, 0)

        self.viewsButtons = {}
        self.current_view = None
        for view in views:
            button = ClockButton(view.label)
            self.buttonBox.pack_start(button, True, True, 0)
            button.connect("toggled", self._on_toggled, view)
            self.viewsButtons[view] = button
            if view.hasSelectionMode:
                view.connect("notify::can-select", self._on_can_select_changed)
            if view == views[0]:
                self.current_view = view
                button.set_active(True)

        self.titleLabel = Gtk.Label()
        self.titleLabel.set_halign(Gtk.Align.CENTER)
        self.titleLabel.set_valign(Gtk.Align.CENTER)
        centerBox.pack_start(self.titleLabel, True, False, 0)

        rightItem = Gtk.ToolItem()
        sizeGroup.add_widget(rightItem)

        rightBox = Gtk.Box()
        rightItem.add(rightBox)
        self.insert(rightItem, -1)

        self.selectButton = SymbolicButton("object-select-symbolic")
        self.selectButton.set_sensitive(self.current_view.can_select)
        self.selectButton.connect('clicked', self._on_select_clicked)
        rightBox.pack_end(self.selectButton, False, False, 0)

        self.editButton = Gtk.Button(_("Edit"))
        self.editButton.set_size_request(64, 34)
        self.editButton.connect('clicked', self._on_edit_clicked)
        rightBox.pack_end(self.editButton, False, False, 0)

        self.doneButton = Gtk.Button(_("Done"))
        self.doneButton.get_style_context().add_class('suggested-action')
        self.doneButton.set_size_request(64, 34)
        self.doneButton.connect("clicked", self._on_done_clicked)
        rightBox.pack_end(self.doneButton, False, False, 0)

        self.selectionHandler = 0

        self.embed._selectionToolbar._toolbarDelete.connect("clicked", self._on_delete_clicked)

    @GObject.Signal(arg_types=(Clock,))
    def view_clock(self, view):
        self.current_view = view

    def activate_view(self, view):
        if view is not self.current_view:
            self.viewsButtons[view].set_active(True)

    def show_overview_toolbar(self):
        self.get_style_context().remove_class("selection-mode")
        self.standalone = None
        self.buttonBox.show()
        self.newButton.set_visible(self.current_view.hasNew)
        self.selectButton.set_visible(self.current_view.hasSelectionMode)
        self.backButton.hide()
        self.titleLabel.hide()
        self.editButton.hide()
        self.doneButton.hide()
        if self.selectionHandler:
            self.current_view.disconnect_by_func(self._on_selection_changed)
            self.selectionHandler = 0

    def show_standalone_toolbar(self, widget):
        self.get_style_context().remove_class("selection-mode")
        self.standalone = widget
        self.buttonBox.hide()
        self.newButton.hide()
        self.selectButton.hide()
        self.backButton.show_all()
        self.titleLabel.set_markup("<b>%s</b>" % self.standalone.get_name())
        self.titleLabel.show()
        self.editButton.set_visible(self.standalone.can_edit)
        self.doneButton.hide()

    def show_selection_toolbar(self):
        self.get_style_context().add_class("selection-mode")
        self.standalone = None
        self.buttonBox.hide()
        self.newButton.hide()
        self.selectButton.hide()
        self.backButton.hide()
        self.set_selection_label(0)
        self.titleLabel.show()
        self.editButton.hide()
        self.doneButton.show()
        self.selectionHandler = \
             self.current_view.connect("selection-changed",
                                        self._on_selection_changed)

    def _on_toggled(self, widget, view):
        self.emit("view-clock", view)

    def set_selection_label(self, n):
        if n == 0:
            self.titleLabel.set_markup("(%s)" % _("Click on items to select them"))
        else:
            msg = ngettext("{0} item selected", "{0} items selected", n).format(n)
            self.titleLabel.set_markup("<b>%s</b>" % (msg))

    def _on_selection_changed(self, view):
        selection = view.get_selection()
        n_selected = len(selection)
        self.set_selection_label(n_selected)
        self.embed.set_show_selectionbar(n_selected > 0)

    def _on_can_select_changed(self, view, pspec):
        if view == self.current_view:
            self.selectButton.set_sensitive(view.can_select)

    def _on_select_clicked(self, button):
        self.show_selection_toolbar()
        self.current_view.set_selection_mode(True)

    def _on_edit_clicked(self, button):
        self.standalone.open_edit_dialog()

    def _on_done_clicked(self, widget):
        self.show_overview_toolbar()
        self.current_view.set_selection_mode(False)
        self.embed.set_show_selectionbar(False)

    def _on_delete_clicked(self, widget):
        self.current_view.delete_selected()
        self.set_selection_label(0)
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
