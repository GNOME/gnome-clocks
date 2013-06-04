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

public class HeaderBar : Gd.HeaderBar {
    public enum Mode {
        NORMAL,
        SELECTION,
        STANDALONE
    }

    private Gd.StackSwitcher stack_switcher;

    [CCode (notify = false)]
    public Mode mode {
        get {
            return _mode;
        }

        set {
            if (_mode != value && get_realized ()) {
                _mode = value;

                custom_title = (_mode == Mode.NORMAL) ? stack_switcher : null;

                if (_mode == Mode.SELECTION) {
                    get_style_context ().add_class ("selection-mode");
                } else {
                    get_style_context ().remove_class ("selection-mode");
                }

                notify_property ("mode");
            }
        }
    }

    private Mode _mode;

    construct {
        stack_switcher = new Gd.StackSwitcher ();
        realize.connect (() => {
            custom_title = stack_switcher;
        });
    }

    public void set_stack (Gd.Stack stack) {
        stack_switcher.set_stack (stack);
    }

    public void clear () {
        foreach (Gtk.Widget w in get_children ()) {
            w.hide ();
        }
    }
}

private class DigitalClockRenderer : Gtk.CellRendererPixbuf {
    public const int TILE_SIZE = 256;
    public const int CHECK_ICON_SIZE = 40;
    public const int TILE_MARGIN = CHECK_ICON_SIZE / 4;
    public const int TILE_MARGIN_BOTTOM = CHECK_ICON_SIZE / 8; // less margin, the text label is below

    public string text { get; set; }
    public string subtext { get; set; }
    public string css_class { get; set; }
    public bool active { get; set; default = false; }
    public bool toggle_visible { get; set; default = false; }

    public DigitalClockRenderer () {
    }

    public override void render (Cairo.Context cr, Gtk.Widget widget, Gdk.Rectangle background_area, Gdk.Rectangle cell_area, Gtk.CellRendererState flags) {
        var context = widget.get_style_context ();

        context.save ();
        context.add_class ("clocks-digital-renderer");
        context.add_class (css_class);

        cr.save ();
        Gdk.cairo_rectangle (cr, cell_area);
        cr.clip ();

        cr.translate (cell_area.x, cell_area.y);

        // the width of the cell which may be larger in case of long city names
        int margin = int.max (TILE_MARGIN, (int) ((cell_area.width - TILE_SIZE) / 2));

        // draw the tile
        if (pixbuf != null) {
            Gdk.Rectangle area = {margin, margin, TILE_SIZE, TILE_SIZE};
            base.render (cr, widget, area, area, flags);
        } else {
            context.render_frame (cr, margin, margin, TILE_SIZE, TILE_SIZE);
            context.render_background (cr, margin, margin, TILE_SIZE, TILE_SIZE);
        }

        int w = cell_area.width - 2 * margin;

        // create the layouts so that we can measure them
        var layout = widget.create_pango_layout ("");
        layout.set_markup ("<span font_desc=\"32.0\">%s</span>".printf (text), -1);
        layout.set_width (w * Pango.SCALE);
        layout.set_alignment (Pango.Alignment.CENTER);
        int text_w, text_h;
        layout.get_pixel_size (out text_w, out text_h);

        Pango.Layout? layout_subtext = null;
        int subtext_w = 0;
        int subtext_h = 0;
        int subtext_pad = 0;
        if (subtext != null) {
            layout_subtext = widget.create_pango_layout ("");
            layout_subtext.set_markup ("<span font_desc=\"14.0\">%s</span>".printf (subtext), -1);
            layout_subtext.set_width (w * Pango.SCALE);
            layout_subtext.set_alignment (Pango.Alignment.CENTER);
            layout_subtext.get_pixel_size (out subtext_w, out subtext_h);
            subtext_pad = 4;
            // We just assume the first line is the longest
            var line = layout_subtext.get_line (0);
            Pango.Rectangle ink_rect, log_rect;
            line.get_pixel_extents (out ink_rect, out log_rect);
            subtext_w = log_rect.width;
        }

        // draw the stripe background
        int stripe_h = 128;
        int x = margin;
        int y = (cell_area.height - stripe_h) / 2;

        context.add_class ("stripe");
        context.render_frame (cr, x, y, w, stripe_h);
        context.render_background (cr, x, y, w, stripe_h);

        // draw text centered on the stripe
        y += (stripe_h - text_h - subtext_h - subtext_pad) / 2;
        context.render_layout (cr, x, y, layout);
        if (subtext != null) {
            y += text_h + subtext_pad;
            context.render_layout (cr, x, y, layout_subtext);
        }

        context.restore ();

        // draw the overlayed checkbox
        if (toggle_visible) {
            int xpad, ypad, x_offset;
            get_padding (out xpad, out ypad);

            if (widget.get_direction () == Gtk.TextDirection.RTL) {
                x_offset = xpad;
            } else {
                x_offset = cell_area.width - CHECK_ICON_SIZE - xpad;
            }

            int check_x = x_offset;
            int check_y = cell_area.height - CHECK_ICON_SIZE - ypad;

            context.save ();
            context.add_class (Gtk.STYLE_CLASS_CHECK);

            if (active) {
                context.set_state (Gtk.StateFlags.ACTIVE);
            }

            context.render_check (cr, check_x, check_y, CHECK_ICON_SIZE, CHECK_ICON_SIZE);

            context.restore ();
        }

        cr.restore ();
    }
}

public interface ContentItem : GLib.Object {
    public abstract string name { get; set; }
    public abstract void get_thumb_properties (out string text, out string subtext, out Gdk.Pixbuf? pixbuf, out string css_class);
}

private class IconView : Gtk.IconView {
    public enum Mode {
        NORMAL,
        SELECTION
    }

    public enum Column {
        SELECTED,
        ITEM,
        COLUMNS
    }

    public Mode mode {
        get {
            return _mode;
        }

        set {
            if (_mode != value) {
                _mode = value;
                // clear selection
                if (_mode != Mode.SELECTION) {
                    unselect_all ();
                }

                thumb_renderer.toggle_visible = (_mode == Mode.SELECTION);
                queue_draw ();
            }
        }
    }

    private Mode _mode;
    private DigitalClockRenderer thumb_renderer;

    public IconView () {
        Object (selection_mode: Gtk.SelectionMode.NONE, mode: Mode.NORMAL);

        model = new Gtk.ListStore (Column.COLUMNS, typeof (bool), typeof (ContentItem));

        get_style_context ().add_class ("content-view");
        set_item_padding (0);
        set_margin (12);

        var tile_width = DigitalClockRenderer.TILE_SIZE + 2 * DigitalClockRenderer.TILE_MARGIN;
        var tile_height = DigitalClockRenderer.TILE_SIZE + DigitalClockRenderer.TILE_MARGIN + DigitalClockRenderer.TILE_MARGIN_BOTTOM;

        thumb_renderer = new DigitalClockRenderer ();
        thumb_renderer.set_alignment (0.5f, 0.5f);
        thumb_renderer.set_fixed_size (tile_width, tile_height);
        pack_start (thumb_renderer, false);
        add_attribute (thumb_renderer, "active", Column.SELECTED);
        set_cell_data_func (thumb_renderer, (column, cell, model, iter) => {
            ContentItem item;
            model.get (iter, IconView.Column.ITEM, out item);
            var renderer = (DigitalClockRenderer) cell;
            string text;
            string subtext;
            Gdk.Pixbuf? pixbuf;
            string css_class;
            item.get_thumb_properties (out text, out subtext, out pixbuf, out css_class);
            renderer.text = text;
            renderer.subtext = subtext;
            renderer.pixbuf = pixbuf;
            renderer.css_class = css_class;
        });

        var text_renderer = new Gtk.CellRendererText ();
        text_renderer.set_alignment (0.5f, 0.5f);
        text_renderer.set_fixed_size (tile_width, -1);
        text_renderer.alignment = Pango.Alignment.CENTER;
        text_renderer.wrap_width = 220;
        text_renderer.wrap_mode = Pango.WrapMode.WORD_CHAR;
        pack_start (text_renderer, true);
        set_cell_data_func (text_renderer, (column, cell, model, iter) => {
            ContentItem item;
            model.get (iter, IconView.Column.ITEM, out item);
            var renderer = (Gtk.CellRendererText) cell;
            renderer.markup = GLib.Markup.escape_text (item.name);
        });
    }

    public override bool button_press_event (Gdk.EventButton event) {
        var path = get_path_at_pos ((int) event.x, (int) event.y);
        if (path != null) {
            // On right click, swicth to selection mode automatically
            if (event.button == Gdk.BUTTON_SECONDARY) {
                mode = Mode.SELECTION;
            }

            if (mode == Mode.SELECTION) {
                var store = (Gtk.ListStore) model;
                Gtk.TreeIter i;
                if (store.get_iter (out i, path)) {
                    bool selected;
                    store.get (i, Column.SELECTED, out selected);
                    store.set (i, Column.SELECTED, !selected);
                    selection_changed ();
                }
            } else {
                item_activated (path);
            }
        }

        return false;
    }

    public void add_item (Object item) {
        var store = (Gtk.ListStore) model;
        Gtk.TreeIter i;
        store.append (out i);
        store.set (i, Column.SELECTED, false, Column.ITEM, item);
    }

    // Redefine selection handling methods since we handle selection manually

    public new List<Gtk.TreePath> get_selected_items () {
        var items = new List<Gtk.TreePath> ();
        model.foreach ((model, path, iter) => {
            bool selected;
            ((Gtk.ListStore) model).get (iter, Column.SELECTED, out selected);
            if (selected) {
                items.prepend (path);
            }
            return false;
        });
        items.reverse ();
        return (owned) items;
    }

    public new void select_all () {
        var model = get_model () as Gtk.ListStore;
        model.foreach ((model, path, iter) => {
            ((Gtk.ListStore) model).set (iter, Column.SELECTED, true);
            return false;
        });
        selection_changed ();
    }

    public new void unselect_all () {
        var model = get_model () as Gtk.ListStore;
        model.foreach ((model, path, iter) => {
            ((Gtk.ListStore) model).set (iter, Column.SELECTED, false);
            return false;
        });
        selection_changed ();
    }

    public void remove_selected () {
        var paths =  get_selected_items ();
        paths.reverse ();
        foreach (Gtk.TreePath path in paths) {
            Gtk.TreeIter i;
            if (((Gtk.ListStore) model).get_iter (out i, path)) {
                ((Gtk.ListStore) model).remove (i);
            }
        }
        selection_changed ();
    }
}

public class ContentView : Gtk.Bin {
    public bool empty { get; private set; default = true; }

    private Gtk.Widget empty_page;
    private IconView icon_view;
    private HeaderBar header_bar;
    private Gd.HeaderSimpleButton select_button;
    private Gd.HeaderSimpleButton cancel_button;
    private GLib.MenuModel selection_menu;
    private Gd.HeaderMenuButton selection_menubutton;
    private Gtk.Frame selection_toolbar;
    private Gtk.Grid grid;
    private Gd.Revealer revealer;
    private Gtk.Button delete_button;

    public ContentView (Gtk.Widget e, HeaderBar b) {
        empty_page = e;
        header_bar = b;

        icon_view = new IconView ();

        select_button = new Gd.HeaderSimpleButton ();
        select_button.symbolic_icon_name = "object-select-symbolic";
        select_button.no_show_all = true;
        bind_property ("empty", select_button, "sensitive", BindingFlags.SYNC_CREATE | BindingFlags.INVERT_BOOLEAN);
        select_button.clicked.connect (() => {
            icon_view.mode = IconView.Mode.SELECTION;
        });
        header_bar.pack_end (select_button);

        cancel_button = new Gd.HeaderSimpleButton ();
        cancel_button.label = _("Cancel");
        cancel_button.no_show_all = true;
        cancel_button.get_style_context ().add_class ("suggested-action");
        cancel_button.clicked.connect (() => {
            icon_view.mode = IconView.Mode.NORMAL;
        });
        header_bar.pack_end (cancel_button);

        var builder = Utils.load_ui ("menu.ui");
        selection_menu = builder.get_object ("selection-menu") as GLib.MenuModel;

        selection_menubutton = new Gd.HeaderMenuButton ();
        selection_menubutton.label = _("Click on items to select them");
        selection_menubutton.menu_model = selection_menu;
        selection_menubutton.get_style_context ().add_class ("selection-menu");

        var scrolled_window = new Gtk.ScrolledWindow (null, null);
        scrolled_window.add (icon_view);
        scrolled_window.hexpand = true;
        scrolled_window.vexpand = true;
        scrolled_window.halign = Gtk.Align.FILL;
        scrolled_window.valign = Gtk.Align.FILL;

        grid = new Gtk.Grid ();
        grid.attach (scrolled_window, 0, 0, 1, 1);

        selection_toolbar = create_selection_toolbar ();
        revealer = new Gd.Revealer ();
        revealer.hexpand = true;
        revealer.halign = Gtk.Align.FILL;
        revealer.add (selection_toolbar);
        grid.attach (revealer, 0, 1, 1, 1);

        var model = icon_view.get_model ();
        model.row_inserted.connect(() => {
            update_empty_view (model);
        });
        model.row_deleted.connect(() => {
            update_empty_view (model);
        });

        icon_view.notify["mode"].connect (() => {
            if (icon_view.mode == IconView.Mode.SELECTION) {
                header_bar.mode = HeaderBar.Mode.SELECTION;
                revealer.reveal_child = true;
            } else if (icon_view.mode == IconView.Mode.NORMAL) {
                header_bar.mode = HeaderBar.Mode.NORMAL;
                revealer.reveal_child = false;
            }
        });

        icon_view.selection_changed.connect (() => {
            var items = icon_view.get_selected_items ();
            var n_items = items.length ();

            string label;
            if (n_items == 0) {
                label = _("Click on items to select them");
            } else {
                label = ngettext ("%d selected", "%d selected", n_items).printf (n_items);
            }
            selection_menubutton.label = label;

            if (n_items != 0) {
                delete_button.sensitive = true;
            } else {
                delete_button.sensitive = false;
            }
        });

        icon_view.item_activated.connect ((path) => {
            var store = (Gtk.ListStore) icon_view.model;
            Gtk.TreeIter i;
            if (store.get_iter (out i, path)) {
                Object item;
                store.get (i, IconView.Column.ITEM, out item);
                item_activated (item);
            }
        });

        add (empty_page);
    }

    public signal void item_activated (Object item);

    public virtual signal void delete_selected () {
        icon_view.remove_selected ();
    }

    private Gtk.Frame create_selection_toolbar () {
        var frame = new Gtk.Frame (null);
        frame.get_style_context ().add_class ("clocks-selection-bar");

        delete_button = new Gtk.Button ();
        delete_button.label = _("Delete");
        delete_button.get_style_context ().add_class ("text-button");
        delete_button.sensitive = false;
        delete_button.halign = Gtk.Align.END;
        delete_button.hexpand = true;
        delete_button.clicked.connect (() => {
            delete_selected ();
            icon_view.mode = IconView.Mode.NORMAL;
        });

        var grid = new Gtk.Grid ();
        grid.attach (delete_button, 0, 0, 1, 1);

        frame.add (grid);
        frame.show_all ();

        return frame;
    }

    private void update_empty_view (Gtk.TreeModel model) {
        Gtk.TreeIter i;

        var child = get_child ();
        if (model.get_iter_first (out i)) {
            if (child != grid) {
                remove (child);
                add (grid);
                empty = false;
            }
        } else {
            if (child != empty_page) {
                remove (child);
                add (empty_page);
                empty = true;
            }
        }
        show_all ();
    }

    public void add_item (ContentItem item) {
        icon_view.add_item (item);
    }

    // Note: this is not efficient: we first walk the model to collect
    // a list then the caller has to walk this list and then it has to
    // delete the items from the view, which walks the model again...
    // Our models are small enough that it does not matter and hopefully
    // we will get rid of GtkListStore/GtkIconView soon.
    public List<Object>? get_selected_items () {
        var items = new List<Object> ();
        var store = (Gtk.ListStore) icon_view.model;
        foreach (Gtk.TreePath path in icon_view.get_selected_items ()) {
            Gtk.TreeIter i;
            if (store.get_iter (out i, path)) {
                Object item;
                store.get (i, IconView.Column.ITEM, out item);
                items.prepend (item);
            }
        }
        items.reverse ();
        return (owned) items;
    }

    public void select_all () {
        icon_view.mode = IconView.Mode.SELECTION;
        icon_view.select_all ();
    }

    public void unselect_all () {
        icon_view.unselect_all ();
    }

    public bool escape_pressed () {
        if (icon_view.mode == IconView.Mode.SELECTION) {
            icon_view.mode = IconView.Mode.NORMAL;
            return true;
        }
        return false;
    }

    public void update_header_bar () {
        switch (header_bar.mode) {
        case HeaderBar.Mode.SELECTION:
            header_bar.custom_title = selection_menubutton;
            cancel_button.show ();
            break;
        case HeaderBar.Mode.NORMAL:
            select_button.show ();
            break;
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
    private Gd.Stack stack;
    private Gtk.Label am_label;
    private Gtk.Label pm_label;

    public AmPmToggleButton () {
        stack = new Gd.Stack ();

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

} // namespace Clocks
