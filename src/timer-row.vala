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
            if (_item == value)
                return;

            if (_item != null) {
                _item.countdown_updated.disconnect (this.update_countdown);
                _item.notify["state"].disconnect (this.update_state);
                name_binding.unbind ();
                entry_binding.unbind ();
            }

            _item = value;

            if (_item != null) {
                _item.countdown_updated.connect (this.update_countdown);
                _item.notify["state"].connect (this.update_state);
                name_binding = _item.bind_property ("name", timer_name, "label",
                                                    BindingFlags.SYNC_CREATE);
                entry_binding = _item.bind_property ("name", title, "text",
                                                     BindingFlags.SYNC_CREATE | BindingFlags.BIDIRECTIONAL);
            }

            update_state ();
        }
    }
    private Item _item;
    private Binding name_binding;
    private Binding entry_binding;
    private Adw.TimedAnimation paused_animation;


    [GtkChild]
    private unowned Gtk.Label countdown_label;

    [GtkChild]
    private unowned Gtk.Label timer_name;

    [GtkChild]
    private unowned Gtk.Stack name_stack;
    [GtkChild]
    private unowned Gtk.Revealer name_revealer;

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

    construct {
        // Force LTR since we do not want to reverse [hh] : [mm] : [ss]
        countdown_label.set_direction (Gtk.TextDirection.LTR);

        delete_button.clicked.connect (() => deleted ());

        var target = new Adw.CallbackAnimationTarget (animation_target);
        paused_animation = new Adw.TimedAnimation (this, 0, 2, 2000, target);
        paused_animation.repeat_count = Adw.DURATION_INFINITE;
        paused_animation.easing = Adw.Easing.LINEAR;

        update_state ();
    }

    public Row (Item item) {
        Object (item: item);
    }

    [GtkCallback]
    private void on_start_button_clicked () {
        if (item != null) {
            item.state = Item.State.RUNNING;
        }
    }

    [GtkCallback]
    private void on_pause_button_clicked () {
        if (item != null) {
            item.state = Item.State.PAUSED;
        }
    }

    [GtkCallback]
    private void on_reset_button_clicked () {
        if (item != null) {
            item.state = Item.State.STOPPED;
        }
    }

    private void update_state () {
        if (item == null || item.state == STOPPED) {
            delete_stack.visible_child_name = "button";
            name_revealer.reveal_child = true;
            name_stack.visible_child_name = "edit";
            reset_stack.visible_child_name = "empty";
            start_stack.visible_child_name = "start";

            countdown_label.add_css_class ("dimmed");
            countdown_label.remove_css_class ("accent");
        } else if (item.state == PAUSED) {
            delete_stack.visible_child_name = "button";
            name_revealer.reveal_child = (timer_name.label != "");
            name_stack.visible_child_name = "display";
            reset_stack.visible_child_name = "button";
            start_stack.visible_child_name = "start";
        } else if (item.state == RUNNING) {
            delete_stack.visible_child_name = "empty";
            name_revealer.reveal_child = (timer_name.label != "");
            name_stack.visible_child_name = "display";
            reset_stack.visible_child_name = "empty";
            start_stack.visible_child_name = "pause";

            countdown_label.add_css_class ("accent");
            countdown_label.remove_css_class ("dimmed");
        }

        if (paused_animation != null) {
            if (item != null && item.state == Item.State.PAUSED) {
                paused_animation.play ();
            } else {
                paused_animation.pause ();
            }
        }

        if (item != null) {
            update_countdown (item.get_stored_hour (), item.get_stored_minute (), item.get_stored_second ());
        } else {
            update_countdown (0, 0, 0);
        }
    }

    private void update_countdown (int h, int m, int s ) {
        countdown_label.set_text ("%02i ∶ %02i ∶ %02i".printf (h, m, s));
    }

    private void animation_target (double val) {
        if (val < 1.0) {
            countdown_label.add_css_class ("dimmed");
            countdown_label.remove_css_class ("accent");
        } else {
            countdown_label.add_css_class ("accent");
            countdown_label.remove_css_class ("dimmed");
        }
    }
}

} // namespace Timer
} // namespace Clocks
