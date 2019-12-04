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

public class Clocks.HeaderBar : Gtk.HeaderBar {
    public enum Mode {
        NORMAL,
        SELECTION,
        STANDALONE
    }

    [CCode (notify = false)]
    public Mode mode {
        get {
            return _mode;
        }

        set {
            if (_mode != value) {
                _mode = value;

                if (_mode == Mode.SELECTION) {
                    get_style_context ().add_class ("selection-mode");
                    button_stack.hide ();
                } else {
                    get_style_context ().remove_class ("selection-mode");
                    button_stack.show ();
                }

                notify_property ("mode");
            }
        }
    }

    public ButtonMode button_mode {
        get {
            return _button_mode;
        }

        set {
            switch (value) {
                case NEW:
                    button_stack.visible_child_name = "new";
                    break;
                case BACK:
                    button_stack.visible_child_name = "back";
                    break;
                case NONE:
                    button_stack.visible_child_name = "none";
                    break;
            }
        }
    }

    private Mode _mode;
    private ButtonMode _button_mode;
    private Gtk.Stack button_stack;

    construct {
        button_stack = new Gtk.Stack ();
        button_stack.homogeneous = true;
        button_stack.transition_type = CROSSFADE;
        button_stack.show ();

        var new_button = new Gtk.Button.from_icon_name ("list-add-symbolic",
                                                        BUTTON);
        new_button.tooltip_text = _("New");
        new_button.action_name = "win.new";
        new_button.show ();
        button_stack.add_named (new_button, "new");

        var back_button = new Gtk.Button.from_icon_name ("go-previous-symbolic",
                                                         BUTTON);
        back_button.tooltip_text = _("Back");
        back_button.action_name = "win.back";
        back_button.show ();
        button_stack.add_named (back_button, "back");

        var empty = new Gtk.Box (VERTICAL, 0);
        empty.show ();
        button_stack.add_named (empty, "none");

        pack_start (button_stack);
    }

    public void clear () {
        custom_title = null;
        foreach (Gtk.Widget w in get_children ()) {
            if (w == button_stack) {
                continue;
            }
            w.hide ();
        }
    }
}
