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
    public abstract void serialize (GLib.VariantBuilder builder);
}

public class ContentStore : GLib.Object, GLib.ListModel {
    private ListStore store;
    private CompareDataFunc sort_func;


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

    public void add (ContentItem item) {
        if (sort_func == null) {
            store.append (item);
        } else {
            store.insert_sorted (item, sort_func);
        }
    }

    public int get_index (ContentItem item) {
        int position = -1;
        var n = store.get_n_items ();
        for (int i = 0; i < n; i++) {
            var compared_item = (ContentItem) store.get_object (i);
            if (compared_item == item) {
                position = i;
                break;
            }
        }
        return position;
    }

    public void remove (ContentItem item) {
        var index = get_index (item);
        if (index != -1) {
            store.remove (index);
        }
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

    public void delete_item (ContentItem item) {
        var n = store.get_n_items ();
        for (int i = 0; i < n; i++) {
            var o = store.get_object (i);
            if (o == item) {
                store.remove (i);

                if (sort_func != null) {
                    store.sort (sort_func);
                }

                return;
            }
        }
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

