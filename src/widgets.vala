/*
 * Copyright (C) 2013  Paolo Borelli <pborelli@gnome.org>
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

public interface ContentItem : GLib.Object {
    public abstract string name { get; set; }
    public abstract bool selectable { get; set; default = true; }
    public abstract bool selected { get; set; default = false; }
    public abstract void serialize (GLib.VariantBuilder builder);
}

public class ContentStore : GLib.Object, GLib.ListModel {
    private ListStore store;
    private CompareDataFunc sort_func;

    public signal void selection_changed ();

    public ContentStore () {
        store = new ListStore (typeof (ContentItem));
        store.items_changed.connect ((position, removed, added) => {
            items_changed (position, removed, added);
        });
    }

    public Type get_item_type () {
        return store.get_item_type ();
    }

    public uint get_n_items () {
        return store.get_n_items ();
    }

    public Object? get_item (uint position) {
        return store.get_item (position);
    }

    public void set_sorting (owned CompareDataFunc sort) {
        sort_func = (owned) sort;

        // TODO: we should re-sort, but for now we only
        // set this before adding any item
        assert (store.get_n_items () == 0);
    }

    private void on_item_selection_toggle (Object o, ParamSpec p) {
        selection_changed ();
    }

    public void add (ContentItem item) {
        if (sort_func == null) {
            store.append (item);
        } else {
            store.insert_sorted (item, sort_func);
        }

        item.notify["selected"].connect (on_item_selection_toggle);
    }

    public delegate void ForeachFunc (ContentItem item);

    public void foreach (ForeachFunc func) {
        var n = store.get_n_items ();
        for (int i = 0; i < n; i++) {
            func (store.get_object (i) as ContentItem);
        }
    }

    public delegate bool FindFunc (ContentItem item);

    public ContentItem? find (FindFunc func) {
        var n = store.get_n_items ();
        for (int i = 0; i < n; i++) {
            var item = store.get_object (i) as ContentItem;
            if (func (item)) {
                return item;
            }
        }
        return null;
    }

    public uint get_n_selected () {
        uint n_selected = 0;
        var n = store.get_n_items ();
        for (int i = 0; i < n; i++) {
            var item = store.get_object (i) as ContentItem;
            if (item.selected) {
                n_selected++;
            }
        }
        return n_selected;
    }

    public void delete_item (ContentItem item) {
        var n = store.get_n_items ();
        for (int i = 0; i < n; i++) {
            var o = store.get_object (i);
            if (o == item) {
                store.remove(i);

                if (sort_func != null) {
                    store.sort (sort_func);
                }
    
                selection_changed ();

                return;
            }
        }
    }

    public void delete_selected () {
        // remove everything and readd the ones not selected
        uint n_deleted = 0;
        Object[] not_selected = {};
        var n = store.get_n_items ();
        for (int i = 0; i < n; i++) {
            var o = store.get_object (i);
            if (!((ContentItem)o).selected) {
                not_selected += o;
            } else {
                n_deleted++;
                SignalHandler.disconnect_by_func (o, (void *)on_item_selection_toggle, (void *)this);
            }
        }

        if (n_deleted > 0) {
            store.splice (0, n, not_selected);
            if (sort_func != null) {
                store.sort (sort_func);
            }

            selection_changed ();
        }
    }

    private void select_unselect_all (bool select) {
        uint n_toggled = 0;

        var n = store.get_n_items ();
        for (int i = 0; i < n; i++) {
            var item = store.get_object (i) as ContentItem;
            var selected = item.selectable && select;
            if (selected != item.selected) {
                SignalHandler.block_by_func (item, (void *)on_item_selection_toggle, (void *)this);
                item.selected = selected;
                SignalHandler.unblock_by_func (item, (void *)on_item_selection_toggle, (void *)this);
                n_toggled++;
            }
        }

        if (n_toggled > 0) {
            selection_changed ();
        }
    }

    public void select_all () {
        select_unselect_all (true);
    }

    public void unselect_all () {
        select_unselect_all (false);
    }

    public Variant serialize () {
        var builder = new GLib.VariantBuilder (new VariantType ("aa{sv}"));
        var n = store.get_n_items ();
        for (int i = 0; i < n; i++) {
            var item = store.get_object (i) as ContentItem;
            item.serialize (builder);
        }
        return builder.end ();
    }

    public delegate ContentItem? DeserializeItemFunc (Variant v);

    public void deserialize (Variant variant, DeserializeItemFunc deserialize_item) {
        foreach (var v in variant) {
            ContentItem? i = deserialize_item (v);
            if (i != null) {
                add (i);
            }
        }
    }
}

private class SelectionMenuButton : Gtk.MenuButton {
    public uint n_items {
        get {
            return _n_items;
        }
        set {
            if (_n_items != value) {
                _n_items = value;
                string label;
                if (n_items == 0) {
                    label = _("Click on items to select them");
                } else {
                    label = ngettext ("%u selected", "%u selected", n_items).printf (n_items);
                }
                menubutton_label.label = label;
            }
        }
    }

    private uint _n_items;
    private Gtk.Label menubutton_label;

    construct {
        var app = (Gtk.Application) GLib.Application.get_default ();
        menu_model = app.get_menu_by_id ("selection-menu");
        menubutton_label = new Gtk.Label (_("Click on items to select them"));
        var arrow = new Gtk.Image.from_icon_name ("pan-down-symbolic", Gtk.IconSize.BUTTON);
        var grid = new Gtk.Grid ();
        grid.set_column_spacing (6);
        grid.attach (menubutton_label, 0, 0, 1, 1);
        grid.attach (arrow, 1, 0, 1, 1);
        add (grid);
        valign = Gtk.Align.CENTER;
        get_style_context ().add_class ("selection-menu");
        show_all ();
    }
}

public class ContentView : Gtk.Bin {
    public ViewMode mode {
        get {
            return _mode;
        }

        set {
            if (_mode != value) {
                _mode = value;

                switch (_mode) {
                    case SELECTION:
                        action_bar.show ();
                        break;
                    case NORMAL:
                    case STANDALONE:
                        action_bar.hide ();
                        // clear current selection
                        model.unselect_all ();
                        break;
                }
            }
        }
    }
    public uint n_selected { get; private set; }

    private ViewMode _mode;
    private ContentStore model;
    private Gtk.FlowBox flow_box;
    private Gtk.Grid grid;
    private Gtk.ActionBar action_bar;
    private Gtk.Button delete_button;

    construct {
        get_style_context ().add_class ("content-view");

        flow_box = new Gtk.FlowBox ();
        flow_box.selection_mode = Gtk.SelectionMode.NONE;
        flow_box.min_children_per_line = 3;

        flow_box.child_activated.connect ((child) => {
            var item = model.get_item (child.get_index ()) as ContentItem;
            if (item != null) {
                item_activated (item);
            }
        });

        var scrolled_window = new Gtk.ScrolledWindow (null, null);
        scrolled_window.add (flow_box);
        scrolled_window.hexpand = true;
        scrolled_window.vexpand = true;
        scrolled_window.halign = Gtk.Align.FILL;
        scrolled_window.valign = Gtk.Align.FILL;

        grid = new Gtk.Grid ();
        grid.attach (scrolled_window, 0, 0, 1, 1);

        action_bar = new Gtk.ActionBar ();
        action_bar.no_show_all = true;
        grid.attach (action_bar, 0, 1, 1, 1);

        delete_button = new Gtk.Button ();
        delete_button.label = _("Delete");
        delete_button.visible = true;
        delete_button.sensitive = false;
        delete_button.halign = Gtk.Align.END;
        delete_button.hexpand = true;
        delete_button.clicked.connect (() => {
            model.delete_selected ();
            mode = NORMAL;
        });

        action_bar.pack_end (delete_button);

        add (grid);
        grid.show_all ();
    }

    public signal void item_activated (ContentItem item);

    public delegate Gtk.Widget ContentViewCreateWidgetFunc (ContentItem item);

    public void bind_model (ContentStore store, owned ContentViewCreateWidgetFunc create_func) {
        model = store;

        model.selection_changed.connect (() => {
            var n_items = model.get_n_selected ();
            n_selected = n_items;

            if (n_items != 0) {
                delete_button.sensitive = true;
            } else {
                delete_button.sensitive = false;
            }
        });

        flow_box.bind_model (model, (object) => {
            var item = (ContentItem) object;
            var inner = create_func (item);

            // wrap the widget in an event box to handle righ-click
            var event_box = new Gtk.EventBox ();
            event_box.add (inner);
            event_box.button_press_event.connect ((event) => {
                // On right click, switch to selection mode automatically
                if (item.selectable && event.button == Gdk.BUTTON_SECONDARY) {
                    mode = SELECTION;
                }

                if (item.selectable && mode == SELECTION) {
                    item.selected = !item.selected;
                    return true;
                } else if (event.button == Gdk.BUTTON_PRIMARY) {
                    item_activated (item);
                    return true;
                }

                return false;
            });

            // wrap the widget in overlay for the selection check box
            var overlay = new Gtk.Overlay ();
            overlay.halign = Gtk.Align.START;
            overlay.valign = Gtk.Align.START;
            overlay.add (event_box);

            var check = new Gtk.CheckButton ();
            check.no_show_all = true;
            check.halign = Gtk.Align.END;
            check.valign = Gtk.Align.END;
            check.margin_bottom = 8;
            check.margin_end = 8;

            item.bind_property ("selected", check, "active", BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE | BindingFlags.BIDIRECTIONAL);
            item.bind_property ("selectable", check, "visible", BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE,
                                 (binding, selectable, ref visible) => {
                visible = this.mode == SELECTION && (item).selectable;
                return true;
            });

            bind_property ("mode", check, "visible", BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE,
                           (binding, mode, ref visible) => {
                visible = mode == ViewMode.SELECTION && (item).selectable;
                return true;
            });

            overlay.add_overlay (check);

            // manually wrap in flowboxchild ourselves since we want to set alignment
            var flow_box_child = new Gtk.FlowBoxChild ();
            flow_box_child.halign = Gtk.Align.START;
            flow_box_child.valign = Gtk.Align.START;
            flow_box_child.add (overlay);
            flow_box_child.get_style_context ().add_class ("tile");

            // flowbox does not handle :hover and setting the PRELIGHT state does not
            // seem to get propagated to the children despite what the documentation
            // says... emulate it ourselves with css classes :(
            event_box.enter_notify_event.connect ((event) => {
                flow_box_child.get_style_context ().add_class ("prelight");
                return false;
            });

            event_box.leave_notify_event.connect ((event) => {
                if (event.detail != Gdk.NotifyType.INFERIOR) {
                    flow_box_child.get_style_context ().remove_class ("prelight");
                }
                return false;
            });

            flow_box_child.show_all ();

            return flow_box_child;
        });
    }

    public void select_all () {
        mode = SELECTION;
        model.select_all ();
    }

    public void unselect_all () {
        model.unselect_all ();
    }

    public bool escape_pressed () {
        if (mode == SELECTION) {
            mode = NORMAL;
            return true;
        }
        return false;
    }
}

public class AmPmToggleButton : Gtk.Button {
    public enum AmPm {
        AM,
        PM
    }

    public AmPm choice {
        get {
            return _choice;
        }
        set {
            if (_choice != value) {
                _choice = value;
                stack.visible_child = _choice == AmPm.AM ? am_label : pm_label;
            }
        }
    }

    private AmPm _choice;
    private Gtk.Stack stack;
    private Gtk.Label am_label;
    private Gtk.Label pm_label;

    public AmPmToggleButton () {
        stack = new Gtk.Stack ();

        get_style_context ().add_class ("clocks-ampm-toggle-button");

        var str = (new GLib.DateTime.utc (1, 1, 1, 0, 0, 0)).format ("%p");
        am_label = new Gtk.Label (str);

        str = (new GLib.DateTime.utc (1, 1, 1, 12, 0, 0)).format ("%p");
        pm_label = new Gtk.Label (str);

        stack.add (am_label);
        stack.add (pm_label);
        add (stack);

        clicked.connect (() => {
            choice = choice == AmPm.AM ? AmPm.PM : AmPm.AM;
        });

        choice = AmPm.AM;
        stack.visible_child = am_label;
        show_all ();
    }
}

public class AnalogFrame : Gtk.Bin {
    protected const int LINE_WIDTH = 6;
    protected const int RADIUS_PAD = 48;

    private int calculate_diameter () {
        int ret = 2 * RADIUS_PAD;
        var child = get_child ();
        if (child != null && child.visible) {
            int w, h;
            child.get_preferred_width (out w, null);
            child.get_preferred_height (out h, null);
            ret += (int) Math.sqrt (w * w + h * h);
        }

        return ret;
    }

    public override void get_preferred_width (out int min_w, out int natural_w) {
        var d = calculate_diameter ();
        min_w = d;
        natural_w = d;
    }

    public override void get_preferred_height (out int min_h, out int natural_h) {
        var d = calculate_diameter ();
        min_h = d;
        natural_h = d;
    }

    public override void size_allocate (Gtk.Allocation allocation) {
        base.size_allocate (allocation);
    }

    public override bool draw (Cairo.Context cr) {
        var context = get_style_context ();

        Gtk.Allocation allocation;
        get_allocation (out allocation);
        var center_x = allocation.width / 2;
        var center_y = allocation.height / 2;

        var radius = calculate_diameter () / 2;

        cr.save ();
        cr.move_to (center_x + radius, center_y);

        context.save ();
        context.add_class ("clocks-analog-frame");

        context.save ();
        context.add_class (Gtk.STYLE_CLASS_TROUGH);

        var color = context.get_color (context.get_state ());

        cr.set_line_width (LINE_WIDTH);
        Gdk.cairo_set_source_rgba (cr, color);
        cr.arc (center_x, center_y, radius - LINE_WIDTH / 2, 0, 2 * Math.PI);
        cr.stroke ();

        context.restore ();

        draw_progress (cr, center_x, center_y, radius);

        context.restore ();
        cr.restore ();

        return base.draw (cr);
    }

    public virtual void draw_progress (Cairo.Context cr, int center_x, int center_y, int radius) {
    }
}

} // namespace Clocks
