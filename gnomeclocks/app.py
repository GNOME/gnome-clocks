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
from clocks import Clock, World, Alarm, Timer, Stopwatch
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
        vbox.pack_start(self.toolbar.selection_toolbar, False, False, 0)

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
        self.toolbar.selection_toolbar.hide()

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

    def _on_view_clock(self, button, view):
        view.unselect_all()
        self.notebook.set_current_page(self.views.index(view))
        self.toolbar._set_overview_toolbar()

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

class SelectionToolbar(Gtk.Toolbar):
    def __init__(self):
        Gtk.Toolbar.__init__(self)
        self.get_style_context().add_class("clocks-toolbar")
        self.set_icon_size(Gtk.IconSize.MENU)
        self.get_style_context().add_class(Gtk.STYLE_CLASS_MENUBAR)
        self.get_style_context().add_class("selection-mode")

        # same size as the button to keep the label centered
        sep = Gtk.SeparatorToolItem()
        sep.set_draw(False)
        sep.set_size_request(64, 34)
        self.insert(sep, -1)

        sep = Gtk.SeparatorToolItem()
        sep.set_draw(False)
        sep.set_expand(True)
        self.insert(sep, -1)

        toolitem = Gtk.ToolItem()
        label = Gtk.Label("(%s)" % _("Click on items to select them"))
        label.set_halign(Gtk.Align.CENTER)
        toolitem.add(label)
        self.insert(toolitem, -1)

        sep = Gtk.SeparatorToolItem()
        sep.set_draw(False)
        sep.set_expand(True)
        self.insert(sep, -1)

        toolitem = Gtk.ToolItem()
        toolbox = Gtk.Box()
        toolitem.add(toolbox)
        self.insert(toolitem, -1)

        self.doneButton = Gtk.Button()

        self.doneButton.get_style_context().add_class('raised')
        self.doneButton.get_style_context().add_class('suggested-action')
        self.doneButton.set_label(_("Done"))
        self.doneButton.set_size_request(64, 34)

        self.leftBox = box = Gtk.Box()
        box.pack_start(self.doneButton, False, False, 0)
        toolbox.pack_start(box, True, True, 0)


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


class ClocksToolbar(Gtk.Toolbar):
    __gsignals__ = {'view-clock': (GObject.SignalFlags.RUN_LAST,
                    None, (Clock,))}

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
        self.newButton.get_style_context().add_class('suggested-action')
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
            lambda w: self.emit("view-clock", self.current_view))

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
        self.applyButton.connect('clicked', self._on_selection_mode, True)
        self.rightBox = box = Gtk.Box()
        box.pack_end(self.applyButton, False, False, 0)
        toolbox.pack_start(box, True, True, 0)

        self.selection_toolbar = SelectionToolbar()
        self.selection_toolbar.doneButton.connect("clicked",
            self._on_selection_mode, False)

    def _on_new_clicked(self, widget):
        self.current_view.open_new_dialog()

    def set_clocks(self, views):
        self.views = views
        for view in views:
            button = ClockButton(view.label)
            self.buttonBox.pack_start(button, False, False, 0)
            button.connect('toggled', self._on_toggled, view)
            if view == views[0]:
                self.current_view = view
                button.set_active(True)

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

    def _on_toggled(self, widget, view):
        self.current_view = view
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

        self.emit("view-clock", view)

    def _on_selection_mode(self, button, selection_mode):
        self.selection_toolbar.set_visible(selection_mode)
        self.set_visible(not selection_mode)

        active_view = None
        for view in self.views:
            if view.button.get_active():
                active_view = view
        active_view.set_selection_mode(selection_mode)

    def _delete_clock(self, button):
        pass


class ClocksApplication(Gtk.Application):
    def __init__(self):
        Gtk.Application.__init__(self)

    def do_activate(self):
        self.win = win = Window(self)
        win.show()

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
