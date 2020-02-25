/*
 * © 2013 Paolo Borelli <pborelli@gnome.org>
 * © 2019 Bilal Elmoussaoui <bilal.elmoussaoui@gnome.org> &
 *        Zander Brown <zbrown@gnome.org>
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


public enum Clocks.ButtonMode {
    NEW,
    BACK,
    NONE
}


public enum Clocks.ViewMode {
    NORMAL,
    STANDALONE
}


[GtkTemplate (ui = "/org/gnome/clocks/ui/headerbar.ui")]
public class Clocks.HeaderBar : Hdy.HeaderBar {
    public ViewMode view_mode {
        get {
            return _mode;
        }

        set {
            _mode = value;

            switch (_mode) {
                case NORMAL:
                    title_stack.visible_child_name = "switcher";
                    start_button_stack.show ();
                    end_button_stack.show ();
                    end_button_stack.visible_child_name = "menu";
                    break;
                case STANDALONE:
                    title_stack.visible_child_name = "title";
                    start_button_stack.show ();
                    end_button_stack.hide ();
                    break;
            }

            visible_child_changed ();
        }
    }

    public ButtonMode button_mode {
        get {
            return _button_mode;
        }

        set {
            switch (value) {
                case NEW:
                    start_button_stack.visible_child_name = "new";
                    break;
                case BACK:
                    start_button_stack.visible_child_name = "back";
                    break;
                case NONE:
                    start_button_stack.visible_child_name = "empty";
                    break;
            }
            _button_mode = value;
        }
    }

    public Gtk.Stack stack { get; set; }
    public Hdy.ViewSwitcherBar switcher_bar { get; set; }
    public string new_label { get; set; }

    private ViewMode _mode;
    private ButtonMode _button_mode;

    [GtkChild]
    private Gtk.Stack start_button_stack;
    [GtkChild]
    private Gtk.Stack end_button_stack;
    [GtkChild]
    private Hdy.Squeezer squeezer;
    [GtkChild]
    private Gtk.Box title_text;
    [GtkChild]
    private Gtk.Stack title_stack;
    [GtkChild]
    private Gtk.Revealer reveal_subtitle;

    [GtkCallback]
    private void subtitle_changed () {
        reveal_subtitle.reveal_child = subtitle != null && subtitle.length > 0;
    }

    [GtkCallback]
    private void visible_child_changed () {
        switcher_bar.reveal = squeezer.visible_child == title_text && view_mode == NORMAL;
    }
}
