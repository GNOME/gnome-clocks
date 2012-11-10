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

import time
from gi.repository import GLib, Gtk
from clocks import Clock


class Stopwatch(Clock):
    LABEL_MARKUP = "<span font_desc=\"64.0\">%02i:%04.1f</span>"
    LABEL_MARKUP_LONG = "<span font_desc=\"64.0\">%i:%02i:%04.1f</span>"
    BUTTON_MARKUP = "<span font_desc=\"18.0\">%s</span>"

    class State:
        RESET = 0
        RUNNING = 1
        STOPPED = 2

    def __init__(self):
        Clock.__init__(self, _("Stopwatch"))

        self.state = Stopwatch.State.RESET

        self.timeout_id = 0

        self.start_time = 0
        self.time_diff = 0

        self.lap = 0
        self.lap_start_time = 0
        self.lap_time_diff = 0

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.add(vbox)

        grid = Gtk.Grid()
        grid.set_margin_top(12)
        grid.set_margin_bottom(48)
        grid.set_halign(Gtk.Align.CENTER)
        grid.set_row_spacing(24)
        grid.set_column_spacing(24)
        grid.set_column_homogeneous(True)
        vbox.pack_start(grid, False, False, 0)

        self.time_label = Gtk.Label()
        self.set_time_label(0, 0, 0)
        grid.attach(self.time_label, 0, 0, 2, 1)

        self.left_button = Gtk.Button()
        self.left_button.set_size_request(200, -1)
        self.left_label = Gtk.Label()
        self.left_label.set_markup(Stopwatch.BUTTON_MARKUP % (_("Start")))
        self.left_button.add(self.left_label)
        self.left_button.get_style_context().add_class("clocks-go")
        grid.attach(self.left_button, 0, 1, 1, 1)

        self.right_button = Gtk.Button()
        self.right_button.set_size_request(200, -1)
        self.right_label = Gtk.Label()
        self.right_label.set_markup(Stopwatch.BUTTON_MARKUP % (_("Reset")))
        self.right_button.add(self.right_label)
        self.right_button.set_sensitive(False)
        grid.attach(self.right_button, 1, 1, 1, 1)

        self.left_button.connect("clicked", self._on_left_button_clicked)
        self.right_button.connect("clicked", self._on_right_button_clicked)

        self.laps_store = Gtk.ListStore(str, str, str)
        cell = Gtk.CellRendererText()
        n_column = Gtk.TreeViewColumn(_("Lap"), cell, markup=0)
        n_column.set_expand(True)
        cell = Gtk.CellRendererText()
        split_column = Gtk.TreeViewColumn(_("Split"), cell, markup=1)
        split_column.set_expand(True)
        cell = Gtk.CellRendererText()
        tot_column = Gtk.TreeViewColumn(_("Total"), cell, markup=2)
        tot_column.set_expand(True)
        self.laps_view = Gtk.TreeView(self.laps_store)
        self.laps_view.get_style_context().add_class("clocks-laps")
        self.laps_view.append_column(n_column)
        self.laps_view.append_column(split_column)
        self.laps_view.append_column(tot_column)
        scroll = Gtk.ScrolledWindow()
        scroll.get_style_context().add_class("clocks-laps-scroll")
        scroll.set_shadow_type(Gtk.ShadowType.IN)
        scroll.set_vexpand(True);
        scroll.add(self.laps_view)
        vbox.pack_start(scroll, True, True, 0)

    def _on_left_button_clicked(self, widget):
        if self.state in (Stopwatch.State.RESET, Stopwatch.State.STOPPED):
            self.state = Stopwatch.State.RUNNING
            self.start()
            self.left_label.set_markup(Stopwatch.BUTTON_MARKUP % (_("Stop")))
            self.left_button.get_style_context().add_class("clocks-stop")
            self.right_button.set_sensitive(True)
            self.right_label.set_markup(Stopwatch.BUTTON_MARKUP % (_("Lap")))
        elif self.state == Stopwatch.State.RUNNING:
            self.state = Stopwatch.State.STOPPED
            self.stop()
            self.left_label.set_markup(Stopwatch.BUTTON_MARKUP % (_("Continue")))
            self.left_button.get_style_context().remove_class("clocks-stop")
            self.left_button.get_style_context().add_class("clocks-go")
            self.right_button.set_sensitive(True)
            self.right_label.set_markup(Stopwatch.BUTTON_MARKUP % (_("Reset")))

    def _on_right_button_clicked(self, widget):
        if self.state == Stopwatch.State.RUNNING:
            self.lap += 1
            tot_h, tot_m, tot_s, split_h, split_m, split_s = self.get_time(True)
            n = "<span color='dimgray'> %d </span>" % (self.lap)
            if split_h > 0:
                s = "<span size ='larger'>%i:%02i:%04.2f</span>" % (split_h, split_m, split_s)
            else:
                s = "<span size ='larger'>%02i:%04.2f</span>" % (split_m, split_s)
            if tot_h:
                t = "<span size ='larger'>%i:%02i:%04.2f</span>" % (tot_h, tot_m, tot_s)
            else:
                t = "<span size ='larger'>%02i:%04.2f</span>" % (tot_m, tot_s)
            i = self.laps_store.append([n, s, t])
            p = self.laps_store.get_path(i)
            self.laps_view.scroll_to_cell(p, None, False, 0, 0)
        if self.state == Stopwatch.State.STOPPED:
            self.state = Stopwatch.State.RESET
            self.reset()
            self.left_label.set_markup(Stopwatch.BUTTON_MARKUP % (_("Start")))
            self.left_button.get_style_context().add_class("clocks-go")
            self.right_button.set_sensitive(False)
            self.set_time_label(0, 0, 0)
            self.laps_store.clear()

    def get_time(self, lap=False):
        curr = time.time()
        diff = curr - self.start_time + self.time_diff
        h, m = divmod(diff, 3600)
        m, s = divmod(m, 60)
        if lap:
            diff = curr - self.lap_start_time + self.lap_time_diff
            lap_h, lap_m = divmod(diff, 3600)
            lap_m, lap_s = divmod(lap_m, 60)
            self.lap_start_time = curr
            return (h, m, s, lap_h, lap_m, lap_s)
        else:
            return (h, m, s)

    def set_time_label(self, h, m, s):
        if h > 0:
            self.time_label.set_markup(Stopwatch.LABEL_MARKUP_LONG % (h, m, s))
        else:
            self.time_label.set_markup(Stopwatch.LABEL_MARKUP % (m, s))

    def _add_timeout(self):
        if self.timeout_id == 0:
            self.timeout_id = GLib.timeout_add(100, self.count)

    def _remove_timeout(self):
        if self.timeout_id != 0:
            GLib.source_remove(self.timeout_id)
        self.timeout_id = 0

    def start(self):
        if self.timeout_id == 0:
            curr = time.time()
            self.start_time = curr
            self.lap_start_time = curr
            self._add_timeout()

    def stop(self):
        curr = time.time()
        self._remove_timeout()
        self.time_diff = self.time_diff + (curr - self.start_time)
        self.lap_time_diff = self.lap_time_diff + (curr - self.lap_start_time)

    def reset(self):
        self.lap = 0
        self.time_diff = 0
        self.lap_time_diff = 0

    def count(self):
        (h, m, s) = self.get_time()
        self.set_time_label(h, m, s)
        return True

    def _ui_freeze(self, widget):
        if self.state == Stopwatch.State.RUNNING:
            self._remove_timeout()

    def _ui_thaw(self, widget):
        if self.state == Stopwatch.State.RUNNING:
            self.count()
            self._add_timeout()
