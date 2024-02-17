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
    public abstract string? name { get; set; }
    public abstract void serialize (GLib.VariantBuilder builder);
}

public class ContentStore : GLib.Object, GLib.ListModel {
    private ListStore store;

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

    public void add (ContentItem item) {
        store.append (item);
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
            func ((ContentItem) store.get_object (i));
        }
    }

    public delegate bool FindFunc (ContentItem item);

    public ContentItem? find (FindFunc func) {
        var n = store.get_n_items ();
        for (int i = 0; i < n; i++) {
            var item = (ContentItem) store.get_object (i);
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

                return;
            }
        }
    }

    public Variant serialize () {
        var builder = new GLib.VariantBuilder (new VariantType ("aa{sv}"));
        var n = store.get_n_items ();
        for (int i = 0; i < n; i++) {
            ((ContentItem) store.get_object (i)).serialize (builder);
        }
        return builder.end ();
    }

    public delegate ContentItem? DeserializeItemFunc (Variant v);

    public void deserialize (Variant variant, DeserializeItemFunc deserialize_item) {
        Variant item;
        var iter = variant.iterator ();
        while (iter.next ("@a{sv}", out item)) {
            ContentItem? i = deserialize_item (item);
            if (i != null) {
                add ((ContentItem) i);
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

        add_css_class ("clocks-ampm-toggle-button");

        var str = (new GLib.DateTime.utc (1, 1, 1, 0, 0, 0)).format ("%p");
        am_label = new Gtk.Label (str);

        str = (new GLib.DateTime.utc (1, 1, 1, 12, 0, 0)).format ("%p");
        pm_label = new Gtk.Label (str);

        stack.add_child (am_label);
        stack.add_child (pm_label);
        set_child (stack);

        clicked.connect (() => {
            choice = choice == AmPm.AM ? AmPm.PM : AmPm.AM;
        });

        choice = AmPm.AM;
        stack.visible_child = am_label;
    }
}


} // namespace Clocks

