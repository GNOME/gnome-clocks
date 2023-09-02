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
    NONE
}

[GtkTemplate (ui = "/org/gnome/clocks/ui/header-bar.ui")]
public class Clocks.HeaderBar : Adw.Bin {
    public ButtonMode button_mode {
        get {
            return _button_mode;
        }

        set {
            switch (value) {
                case NEW:
                    start_button_stack.visible_child_name = "new";
                    break;
                case NONE:
                    start_button_stack.visible_child_name = "empty";
                    break;
            }
            _button_mode = value;
        }
    }

    public Gtk.Widget title_widget {
        get {
            return header_bar.title_widget;
        }

        set {
            header_bar.title_widget = value;
        }
    }

    public Adw.ViewStack stack { get; set; }
    public Adw.ViewSwitcherBar switcher_bar { get; set; }
    public string? new_label { get; set; }

    private ButtonMode _button_mode;

    [GtkChild]
    private unowned Adw.ViewStack start_button_stack;
    [GtkChild]
    private unowned Adw.HeaderBar header_bar;

}
