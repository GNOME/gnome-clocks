/*
 * Copyright (C) 2013  Paolo Borelli <pborelli@gnome.org>
 * Copyright (C) 2020  Bilal Elmoussaoui <bilal.elmoussaoui@gnome.org>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

namespace Clocks {
namespace Timer {

[GtkTemplate (ui = "/org/gnome/clocks/ui/timer-row.ui")]
public class Row : Gtk.ListBoxRow {
    public Item item {
        get {
            return _item;
        }

        construct set {
            _item = value;

            title.text = (string) _item.name;
            title.bind_property ("text", _item, "name");
            timer_name.label = (string) _item.name;
            title.bind_property ("text", timer_name, "label");

            _item.notify["name"].connect (() => edited ());
        }
    }
    private Item _item;


    [GtkChild]
    private unowned Gtk.Label countdown_label;

    [GtkChild]
    private unowned Gtk.Label timer_name;

    [GtkChild]
    private unowned Gtk.Stack name_stack;

    [GtkChild]
    private unowned Gtk.Stack start_stack;
    [GtkChild]
    private unowned Gtk.Stack reset_stack;
    [GtkChild]
    private unowned Gtk.Stack delete_stack;

    [GtkChild]
    private unowned Gtk.Button delete_button;
    [GtkChild]
    private unowned Gtk.Entry title;

    public signal void deleted ();
    public signal void edited ();

    public Row (Item item) {
        Object (item: item);

        // Force LTR since we do not want to reverse [hh] : [mm] : [ss]
        countdown_label.set_direction (Gtk.TextDirection.LTR);

        item.countdown_updated.connect (this.update_countdown);
        item.ring.connect (() => this.ring ());
        item.start.connect (() => this.start ());
        item.pause.connect (() => this.pause ());
        item.reset.connect (() => this.reset ());
        delete_button.clicked.connect (() => deleted ());

        reset ();
    }

    [GtkCallback]
    private void on_start_button_clicked () {
        item.start ();
    }

    [GtkCallback]
    private void on_pause_button_clicked () {
        item.pause ();
    }

    [GtkCallback]
    private void on_reset_button_clicked () {
        item.reset ();
    }

    private void reset () {
        reset_stack.visible_child_name = "empty";
        delete_stack.visible_child_name = "button";

        countdown_label.get_style_context ().remove_class ("timer-paused");
        countdown_label.get_style_context ().remove_class ("timer-ringing");
        countdown_label.get_style_context ().remove_class ("timer-running");
        start_stack.visible_child_name = "start";
        name_stack.visible_child_name = "edit";

        update_countdown (item.hours, item.minutes, item.seconds);
    }

    private void start () {
        countdown_label.get_style_context ().add_class ("timer-running");
        countdown_label.get_style_context ().remove_class ("timer-ringing");
        countdown_label.get_style_context ().remove_class ("timer-paused");

        reset_stack.visible_child_name = "empty";
        delete_stack.visible_child_name = "empty";

        start_stack.visible_child_name = "pause";
        name_stack.visible_child_name = "display";
    }

    private void ring () {
        countdown_label.get_style_context ().add_class ("timer-ringing");
        countdown_label.get_style_context ().remove_class ("timer-paused");
        countdown_label.get_style_context ().remove_class ("timer-running");
    }

    private void pause () {
        countdown_label.get_style_context ().add_class ("timer-paused");
        countdown_label.get_style_context ().remove_class ("timer-ringing");
        countdown_label.get_style_context ().remove_class ("timer-running");

        reset_stack.visible_child_name = "button";
        delete_stack.visible_child_name = "button";
        start_stack.visible_child_name = "start";
        name_stack.visible_child_name = "display";
    }

    private void update_countdown (int h, int m, int s ) {
        countdown_label.set_text ("%02i ∶ %02i ∶ %02i".printf (h, m, s));
    }
}

} // namespace Timer
} // namespace Clocks
