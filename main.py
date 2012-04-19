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

from gi.repository import Gtk, Gio, GObject, Gdk

from clocks import World, Alarm, Timer, Stopwatch

class Window (Gtk.Window):
    def __init__ (self):
        Gtk.Window.__init__ (self)
        css_provider = Gtk.CssProvider()
        css_provider.load_from_path("gtk-style.css")
        context = Gtk.StyleContext()
        context.add_provider_for_screen (Gdk.Screen.get_default (),
                                         css_provider,
                                         Gtk.STYLE_PROVIDER_PRIORITY_USER)
        
        self.set_size_request(640, 480)
        self.set_title("Clocks")
        self.vbox  = vbox = Gtk.VBox()
        self.add (vbox)
        self.notebook = Gtk.Notebook ()
        self.notebook.set_show_tabs (False)
        
        self.toolbar = ClocksToolbar ()
        
        vbox.pack_start (self.toolbar, False, False, 0)
        
        self.world = World ()
        self.alarm = Alarm ()
        self.stopwatch = Stopwatch ()
        self.timer = Timer ()
        
        self.views = (self.world, self.alarm, self.stopwatch, self.timer)
        self.toolbar.set_clocks (self.views)
        
        self.show_all ()
        
        vbox.pack_end (self.notebook, True, True, 0)
        vbox.pack_end (Gtk.Separator(), False, False, 1)
        for view in self.views:
            self.notebook.append_page (view, Gtk.Label(str(view)))
        
        self.toolbar.connect("view-clock", self._on_view_clock)
        self.toolbar.newButton.connect("clicked", self._on_new_clicked)
        self.show_all ()
        
        
    def _on_view_clock (self, button, index):
        self.notebook.set_current_page (index)
        
    def _on_new_clicked (self, button):
        self.show_all()
    
    def _on_cancel_clicked (self, button):
        self.show_all()

class ClocksToolbar (Gtk.Toolbar):
    __gsignals__ = {'view-clock': (GObject.SignalFlags.RUN_LAST,
                    None, (GObject.TYPE_INT,))}
    def __init__ (self):
        Gtk.Toolbar.__init__ (self)
        self.get_style_context ().add_class ("osd");
        self.set_size_request(-1, -1)
        self.get_style_context ().add_class (Gtk.STYLE_CLASS_MENUBAR);
        
        toolitem = Gtk.ToolItem ()
        toolitem.set_expand (True)
        
        toolbox = Gtk.Box()
        toolitem.add(toolbox)
        self.insert(toolitem, -1)
        
        self.views = []
        
        self.newButton = Gtk.Button ()
        
        label = Gtk.Label ("  New  ")
        self.newButton.get_style_context ().add_class ('raised');
        self.newButton.add(label)
        
        self.leftBox = box = Gtk.Box ()
        box.pack_start (self.newButton, False, False, 3)
        toolbox.pack_start (box, True, True, 0)
        
        self.newButton.connect("clicked", self._on_new_clicked)
        
        toolbox.pack_start (Gtk.Label(""), True, True, 0)
        
        self.buttonBox = Gtk.Box ()
        self.buttonBox.set_homogeneous (True)
        self.buttonBox.get_style_context ().add_class ("linked")
        toolbox.pack_start (self.buttonBox, False, False, 0)
        
        toolbox.pack_start (Gtk.Label(""), True, True, 0)
        
        self.applyButton = Gtk.Button ()
        #self.applyButton.get_style_context ().add_class ('raised');
        icon = Gio.ThemedIcon.new_with_default_fallbacks ("action-unavailable-symbolic")
        image = Gtk.Image ()
        image.set_from_gicon (icon, Gtk.IconSize.LARGE_TOOLBAR)
        self.applyButton.add (image)
        self.rightBox = box = Gtk.Box ()
        box.pack_end (self.applyButton, False, False, 3)
        toolbox.pack_start (box, True, True, 0)
        
        self._buttonMap = {}
        self._busy = False

    def _on_new_clicked (self, widget):
        for view in self.views:
            if view.button.get_active():
                view.open_new_dialog()
                break
    
    def _on_cancel_clicked (self, widget):
        for view in self.views:
            if view.button.get_active():
                view.close_new_dialog()
                break

    def set_clocks (self, views):
        self.views = views
        for i, view in enumerate(views):
            self.buttonBox.pack_start (view.button, False, False, 0)
            view.button.get_style_context ().add_class ('linked');
            #view.button.get_style_context ().add_class ('raised');
            view.button.connect ('toggled', self._on_toggled)
            self._buttonMap[view.button] = i
            if i == 0:
                view.button.set_active (True)

    def _on_toggled (self, widget):
        if not self._busy:
            self._busy = True
            for view in self.views:
                if not view.button == widget:
                    view.button.set_active (False)
                else:
                    view.button.set_active (True)
                    if view.hasNew:
                        self.newButton.get_children()[0].show_all()
                        self.newButton.show_all()
                        self.newButton.set_relief (Gtk.ReliefStyle.NORMAL)
                        self.newButton.set_sensitive (True)
                    else:
                        width = self.newButton.get_allocation().width
                        self.newButton.set_relief (Gtk.ReliefStyle.NONE)
                        self.newButton.set_sensitive (False)
                        self.newButton.set_size_request(width, -1)
                        self.newButton.get_children()[0].hide()

            self._busy = False
            self.emit ("view-clock", self._buttonMap[widget])

if __name__=="__main__":
    window = Window()
    window.connect("destroy", lambda w: Gtk.main_quit())
    Gtk.main()

