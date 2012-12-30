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
from gi.repository import Gtk, Gdk, Gio, GtkClutter
from world import World
from alarm import Alarm
from stopwatch import Stopwatch
from timer import Timer
from widgets import Toolbar, Embed
from utils import Dirs
from gnomeclocks import VERSION, AUTHORS, COPYRIGHTS


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
        css_provider.load_from_path(os.path.join(Dirs.get_css_dir(),
                                                 "gnome-clocks.css"))
        context = Gtk.StyleContext()
        context.add_provider_for_screen(Gdk.Screen.get_default(),
                                        css_provider,
                                        Gtk.STYLE_PROVIDER_PRIORITY_USER)

        self.set_size_request(640, 480)

        self.toolbar = Toolbar()
        self.toolbar.connect("page-changed", self._on_page_changed)

        self.notebook = Gtk.Notebook()
        self.notebook.set_show_tabs(False)
        self.notebook.set_show_border(False)

        self.embed = Embed(self.notebook)

        self.world = World(self.toolbar, self.embed)
        self.alarm = Alarm(self.toolbar, self.embed)
        self.stopwatch = Stopwatch(self.toolbar, self.embed)
        self.timer = Timer(self.toolbar, self.embed)
        self.alarm.connect("alarm-ringing", self._on_alarm_ringing)
        self.timer.connect("alarm-ringing", self._on_alarm_ringing)
        self.views = (self.world, self.alarm, self.stopwatch, self.timer)

        for view in self.views:
            self.toolbar.append_page(view.label)
            self.notebook.append_page(view, None)
        self.notebook.set_current_page(0)
        self.world.update_toolbar()

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        vbox.pack_start(self.toolbar, False, False, 0)
        vbox.pack_end(self.embed, True, True, 0)

        self.add(vbox)
        vbox.show()

    def _on_new_activated(self, action, param):
        view = self.views[self.notebook.get_current_page()]
        view.activate_new()

    def _on_alarm_ringing(self, view):
        self.notebook.set_current_page(self.views.index(view))

    def _on_page_changed(self, toolbar, page):
        self.notebook.set_current_page(page)
        view = self.views[self.notebook.get_current_page()]
        view.update_toolbar()

    def _on_about_activated(self, action, param):
        about = Gtk.AboutDialog()
        about.set_title(_("About Clocks"))
        about.set_program_name(_("GNOME Clocks"))
        about.set_logo_icon_name("gnome-clocks")
        about.set_version(VERSION)
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


class Application(Gtk.Application):
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
