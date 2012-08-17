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

from gi.repository import Gtk, Gdk, GObject, Gio
from clocks import World, Alarm, Timer, Stopwatch
from utils import Dirs
from gnomeclocks import __version__, AUTHORS, COPYRIGHTS


class Window(Gtk.ApplicationWindow):
    def __init__(self, app):
        Gtk.ApplicationWindow.__init__(self, title=_("Clocks"),
                                       application=app,
                                       hide_titlebar_when_maximized=True)

        self.app = app

        css_provider = Gtk.CssProvider()
        css_provider.load_from_path(os.path.join(Dirs.get_data_dir(),
                                                 "gtk-style.css"))
        context = Gtk.StyleContext()
        context.add_provider_for_screen(Gdk.Screen.get_default(),
                                         css_provider,
                                         Gtk.STYLE_PROVIDER_PRIORITY_USER)

        self.set_size_request(640, 480)
        self.vbox = vbox = Gtk.VBox()
        self.add(vbox)
        self.notebook = Gtk.Notebook()
        self.notebook.set_show_tabs(False)
        self.notebook.set_show_border(False)

        self.toolbar = ClocksToolbar()

        vbox.pack_start(self.toolbar, False, False, 0)

        self.world = World()
        self.alarm = Alarm()
        self.stopwatch = Stopwatch()
        self.timer = Timer()

        self.views = (self.world, self.alarm, self.stopwatch, self.timer)
        self.toolbar.set_clocks(self.views)
        self.single_evbox = Gtk.EventBox()

        vbox.pack_end(self.notebook, True, True, 0)
        for view in self.views:
            self.notebook.append_page(view, Gtk.Label(str(view)))
        self.notebook.append_page(self.single_evbox, Gtk.Label("Widget"))

        self.world.connect("show-clock", self._on_show_clock)
        self.toolbar.connect("view-clock", self._on_view_clock)
        self.toolbar.newButton.connect("clicked", self._on_new_clicked)
        self.show_all()

        self.connect('key-press-event', self._on_key_press)

    def _set_up_menu(self):
        pass

    def _on_show_clock(self, widget, d):
        self.toolbar._set_single_toolbar()
        self.notebook.set_current_page(-1)
        for child in self.single_evbox.get_children():
            self.single_evbox.remove(child)
        self.single_evbox.add(d.get_standalone_widget())
        self.single_evbox.show_all()
        self.toolbar.city_label.set_markup("<b>" + d.id + "</b>")

    def _on_view_clock(self, button, index):
        self.notebook.set_current_page(index)
        self.toolbar._set_overview_toolbar()
        self.notebook.get_nth_page(index).unselect_all()

    def _on_new_clicked(self, button):
        self.show()

    def _on_cancel_clicked(self, button):
        self.show()

    def show_about(self):
        about = Gtk.AboutDialog(title=_("About GNOME Clocks"))
        about.set_title(_("About Clocks"))
        about.set_program_name(_("GNOME Clocks"))
        about.set_logo_icon_name("clocks")
        about.set_version(__version__)
        about.set_copyright(COPYRIGHTS)
        about.set_comments(
            _("Utilities to help you with the time."))
        about.set_authors(AUTHORS)
        about.set_translator_credits(_("translator-credits"))
        about.connect("response", lambda w, r: about.destroy())
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
        about.set_modal(True)
        about.set_transient_for(self)
        about.show()

    def _on_key_press(self, widget, event):
        keyname = Gdk.keyval_name(event.keyval)
        if event.state and Gdk.ModifierType.CONTROL_MASK:
            if keyname == 'n':
                self.toolbar._on_new_clicked(None)
            elif keyname in ('q', 'w'):
                self.app.quit()


class ClocksToolbar(Gtk.Toolbar):
    __gsignals__ = {'view-clock': (GObject.SignalFlags.RUN_LAST,
                    None, (GObject.TYPE_INT,))}

    def __init__(self):
        Gtk.Toolbar.__init__(self)
        self.get_style_context().add_class("clocks-toolbar")

        self.set_icon_size(Gtk.IconSize.MENU)
        self.get_style_context().add_class(Gtk.STYLE_CLASS_MENUBAR)

        toolitem = Gtk.ToolItem()
        toolitem.set_expand(True)

        toolbox = Gtk.Box()
        toolitem.add(toolbox)
        self.insert(toolitem, -1)

        self.views = []

        self.newButton = Gtk.Button()

        label = Gtk.Label(_("New"))
        self.newButton.get_style_context().add_class('raised')
        self.newButton.add(label)
        self.newButton.set_size_request(64, -1)

        self.leftBox = box = Gtk.Box()
        box.pack_start(self.newButton, False, False, 0)
        toolbox.pack_start(box, True, True, 0)

        self.backButton = Gtk.Button()
        icon = Gio.ThemedIcon.new_with_default_fallbacks(
            "go-previous-symbolic")
        image = Gtk.Image()
        image.set_from_gicon(icon, Gtk.IconSize.MENU)
        self.backButton.add(image)
        self.backButton.set_size_request(33, 33)
        self.backButton.connect("clicked",
            lambda w: self.emit("view-clock",
                                self._buttonMap[self.last_widget]))

        self.newButton.connect("clicked", self._on_new_clicked)

        toolbox.pack_start(Gtk.Label(""), True, True, 0)

        self.buttonBox = Gtk.Box()
        self.buttonBox.set_homogeneous(True)
        self.buttonBox.get_style_context().add_class("linked")
        toolbox.pack_start(self.buttonBox, False, False, 0)

        self.city_label = Gtk.Label()
        toolbox.pack_start(self.city_label, False, False, 0)
        toolbox.pack_start(Gtk.Box(), False, False, 15)

        toolbox.pack_start(Gtk.Label(""), True, True, 0)

        self.applyButton = Gtk.Button()
        #self.applyButton.get_style_context().add_class('raised');
        icon = Gio.ThemedIcon.new_with_default_fallbacks(
            "object-select-symbolic")
        image = Gtk.Image()
        image.set_from_gicon(icon, Gtk.IconSize.MENU)
        self.applyButton.add(image)
        self.applyButton.set_size_request(32, 32)
        self.applyButton.connect('clicked', self._on_selection_mode)
        self.rightBox = box = Gtk.Box()
        box.pack_end(self.applyButton, False, False, 0)
        toolbox.pack_start(box, True, True, 0)

        self._buttonMap = {}
        self._busy = False

    def _on_new_clicked(self, widget):
        for view in self.views:
            if view.button.get_active():
                view.open_new_dialog()
                break
        self._set_overview_toolbar()
        self.backButton.hide()
        self.city_label.hide()

    def set_clocks(self, views):
        self.views = views
        for i, view in enumerate(views):
            self.buttonBox.pack_start(view.button, False, False, 0)
            view.button.get_style_context().add_class('linked')
            #view.button.get_style_context().add_class('raised')
            view.button.connect('toggled', self._on_toggled)
            self._buttonMap[view.button] = i
            if i == 0:
                view.button.set_active(True)

    def _set_overview_toolbar(self):
        self.buttonBox.show()
        self.newButton.show()
        self.applyButton.show()
        self.backButton.hide()
        self.city_label.hide()

    def _set_single_toolbar(self):
        self.buttonBox.hide()
        self.newButton.hide()
        self.applyButton.hide()
        if not self.backButton.get_parent():
            self.leftBox.pack_start(self.backButton, False, False, 0)
        self.backButton.show_all()
        self.city_label.show()

    def _on_toggled(self, widget):
        if not self._busy:
            self._busy = True
            for view in self.views:
                if not view.button == widget:
                    view.button.set_active(False)
                else:
                    view.button.set_active(True)
                    if view.hasNew:
                        self.newButton.get_children()[0].show_all()
                        self.newButton.show_all()
                        self.newButton.set_relief(Gtk.ReliefStyle.NORMAL)
                        self.newButton.set_sensitive(True)
                    else:
                        width = self.newButton.get_allocation().width
                        self.newButton.set_relief(Gtk.ReliefStyle.NONE)
                        self.newButton.set_sensitive(False)
                        self.newButton.set_size_request(width, -1)
                        self.newButton.get_children()[0].hide()
                    if view.hasSelectionMode:
                        self.applyButton.get_children()[0].show_all()
                        self.applyButton.show_all()
                        self.applyButton.set_relief(Gtk.ReliefStyle.NORMAL)
                        self.applyButton.set_sensitive(True)
                    else:
                        width = self.applyButton.get_allocation().width
                        self.applyButton.set_relief(Gtk.ReliefStyle.NONE)
                        self.applyButton.set_sensitive(False)
                        self.applyButton.set_size_request(width, -1)
                        self.applyButton.get_children()[0].hide()

            self.last_widget = widget
            self._busy = False
            self.emit("view-clock", self._buttonMap[widget])

    def _on_selection_mode(self, button):
        self.set_selection_mode(True)

    def set_selection_mode(self, val):
        if val == True:
            pass
        else:
            self.set_single_toolbar()

    def _delete_clock(self, button):
        pass


class ClocksApplication(Gtk.Application):
    def __init__(self):
        Gtk.Application.__init__(self)

    def do_activate(self):
        self.win = win = Window(self)
        win.show_all()

    def quit_cb(self, action, parameter):
        self.quit()

    def about_cb(self, action, parameter):
        self.win.show_about()

    def do_startup(self):
        Gtk.Application.do_startup(self)

        menu = Gio.Menu()

        menu.append(_("About Clocks"), "app.about")
        menu.append(_("Quit"), "app.quit")
        self.set_app_menu(menu)

        about_action = Gio.SimpleAction.new("about", None)
        about_action.connect("activate", self.about_cb)
        self.add_action(about_action)

        quit_action = Gio.SimpleAction.new("quit", None)
        quit_action.connect("activate", self.quit_cb)
        self.add_action(quit_action)
