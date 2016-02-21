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

public class HeaderBar : Gtk.HeaderBar {
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
                } else {
                    get_style_context ().remove_class ("selection-mode");
                }

                notify_property ("mode");
            }
        }
    }

    private Mode _mode;

    public void clear () {
        custom_title = null;
        foreach (Gtk.Widget w in get_children ()) {
            w.hide ();
        }
    }
}

private class TitleRenderer : Gtk.CellRendererText {
    private int ICON_XOFF;
    private int ICON_YOFF;
    private int ICON_SIZE;

    public string title {
        get {
            return _title;
        }
        set {
            markup = _title = value;
        }
    }

    public string title_icon { get; set; default = null; }

    private string _title;

    public TitleRenderer () {
        ICON_YOFF = 5;
        ICON_XOFF = 25;
        ICON_SIZE = 18;
    }

    public override void render (Cairo.Context cr,
                                 Gtk.Widget widget,
                                 Gdk.Rectangle background_area,
                                 Gdk.Rectangle cell_area,
                                 Gtk.CellRendererState flags) {
        base.render (cr, widget, cell_area, cell_area, flags);

        if (title_icon != null) {
            var context = widget.get_style_context ();
            context.save ();

            cr.save ();
            Gdk.cairo_rectangle (cr, cell_area);
            cr.clip ();

            cr.translate (cell_area.x, cell_area.y);

            // create the layouts so that we can measure them
            var layout = widget.create_pango_layout ("");
            layout.set_markup (title, -1);
            layout.set_alignment (Pango.Alignment.CENTER);
            int text_w, text_h;
            layout.get_pixel_size (out text_w, out text_h);

            int x = (cell_area.width - text_w) / 2 - ICON_XOFF, y = ICON_YOFF;

            if (widget.get_direction () == Gtk.TextDirection.RTL) {
                x = (cell_area.width + text_w) / 2 + ICON_XOFF - ICON_SIZE;
            }

            Gtk.IconTheme icon_theme = Gtk.IconTheme.get_for_screen (Gdk.Screen.get_default ());
            try {
                Gtk.IconInfo? icon_info = icon_theme.lookup_icon_for_scale (title_icon, ICON_SIZE, widget.scale_factor, 0);
                assert (icon_info != null);

                Cairo.Surface surface = icon_info.load_surface (widget.get_window ());
                Gtk.render_icon_surface (context, cr, surface, x, y);
            } catch (Error e) {
                warning (e.message);
            }

            context.restore ();
            cr.restore ();
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
    public bool checked { get; set; default = false; }
    public bool toggle_visible { get; set; default = false; }
    public bool selectable { get; set; default = true; }

    public DigitalClockRenderer () {
    }

    public override void render (Cairo.Context cr,
                                 Gtk.Widget widget,
                                 Gdk.Rectangle background_area,
                                 Gdk.Rectangle cell_area,
                                 Gtk.CellRendererState flags) {
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
            context.render_background (cr, margin, margin, TILE_SIZE, TILE_SIZE);
        }
        context.render_frame (cr, margin, margin, TILE_SIZE, TILE_SIZE);

        var border = context.get_border(context.get_state ());
        int w = cell_area.width - 2 * margin - border.left - border.right;

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
        int x = margin + border.left;
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
        if (selectable && toggle_visible) {
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
            context.add_class ("clocks-digital-renderer-check");
            context.add_class (css_class);

            if (checked) {
                context.set_state (Gtk.StateFlags.CHECKED);
            }

            context.render_background (cr, check_x, check_y, CHECK_ICON_SIZE, CHECK_ICON_SIZE);
            context.render_frame (cr, check_x, check_y, CHECK_ICON_SIZE, CHECK_ICON_SIZE);
            context.render_check (cr, check_x, check_y, CHECK_ICON_SIZE, CHECK_ICON_SIZE);

            context.restore ();
        }

        cr.restore ();
    }
}

public interface ContentItem : GLib.Object {
    public abstract string name { get; set; }
    public abstract string title_icon { get; set; default = null; }
    public abstract bool selectable { get; set; default = true; }
    public abstract bool selected { get; set; default = false; }

    public abstract void get_thumb_properties (out string text,
                                               out string subtext,
                                               out Gdk.Pixbuf? pixbuf,
                                               out string css_class);

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

    public void set_sorting(owned CompareDataFunc sort) {
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

    public delegate void ForeachFunc(ContentItem item);

    public void foreach(ForeachFunc func) {
        var n = store.get_n_items ();
        for (int i = 0; i < n; i++) {
            func(store.get_object (i) as ContentItem);
        }
    }

    public delegate bool FindFunc(ContentItem item);

    public ContentItem? find(FindFunc func) {
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
            store.splice(0, n, not_selected);
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

    public delegate ContentItem? DeserializeItemFunc(Variant v);

    public void deserialize (Variant variant, DeserializeItemFunc deserialize_item) {
        foreach (var v in variant) {
            ContentItem? i = deserialize_item (v);
            if (i != null) {
                add (i);
            }
        }
    }
}

private class IconView : Gtk.IconView {
    public enum Mode {
        NORMAL,
        SELECTION
    }

    public Mode mode { get; set; }

    public IconView () {
        Object (selection_mode: Gtk.SelectionMode.NONE, mode: Mode.NORMAL);

        model = new Gtk.ListStore (1, typeof (ContentItem));

        get_style_context ().add_class ("clocks-tiles-view");
        get_style_context ().add_class ("content-view");
        set_item_padding (0);
        set_margin (12);

        var tile_width = DigitalClockRenderer.TILE_SIZE + 2 * DigitalClockRenderer.TILE_MARGIN;
        var tile_height = DigitalClockRenderer.TILE_SIZE +
                          DigitalClockRenderer.TILE_MARGIN +
                          DigitalClockRenderer.TILE_MARGIN_BOTTOM;

        var thumb_renderer = new DigitalClockRenderer ();
        thumb_renderer.set_alignment (0.5f, 0.5f);
        thumb_renderer.set_fixed_size (tile_width, tile_height);
        pack_start (thumb_renderer, false);
        set_cell_data_func (thumb_renderer, (column, cell, model, iter) => {
            ContentItem? item;
            model.get (iter, 0, out item);
            if (item != null) {
                var renderer = (DigitalClockRenderer) cell;
                string text;
                string subtext;
                Gdk.Pixbuf? pixbuf;
                string css_class;
                item.get_thumb_properties (out text, out subtext, out pixbuf, out css_class);
                renderer.selectable = item.selectable;
                renderer.toggle_visible = (mode == Mode.SELECTION);
                renderer.checked = item.selected;
                renderer.text = text;
                renderer.subtext = subtext;
                renderer.pixbuf = pixbuf;
                renderer.css_class = css_class;
            }
        });

        var title_renderer = new TitleRenderer ();
        title_renderer.set_alignment (0.5f, 0.5f);
        title_renderer.set_fixed_size (tile_width, -1);
        title_renderer.alignment = Pango.Alignment.CENTER;
        title_renderer.wrap_width = 220;
        title_renderer.wrap_mode = Pango.WrapMode.WORD_CHAR;
        pack_start (title_renderer, true);
        set_cell_data_func (title_renderer, (column, cell, model, iter) => {
            ContentItem? item;
            model.get (iter, 0, out item);
            if (item != null) {
                var renderer = (TitleRenderer) cell;
                renderer.title = GLib.Markup.escape_text (item.name);
                renderer.title_icon = item.title_icon;
            }
        });
    }

    public override bool button_press_event (Gdk.EventButton event) {
        var path = get_path_at_pos ((int) event.x, (int) event.y);
        if (path != null) {
            var store = (Gtk.ListStore) model;
            Gtk.TreeIter i;
            if (store.get_iter (out i, path)) {
                ContentItem item;
                store.get (i, 0, out item);
                if (item != null) {
                    // On right click, swicth to selection mode automatically
                    if (item.selectable && event.button == Gdk.BUTTON_SECONDARY) {
                        mode = Mode.SELECTION;
                    }

                    if (item.selectable && mode == Mode.SELECTION) {
                        item.selected = !item.selected;
                        selection_changed ();
                    } else if (event.button == Gdk.BUTTON_PRIMARY) {
                        item_activated (path);
                    }
                }
            }
        }

        return false;
    }

    public void add_item (Object item) {
        var store = (Gtk.ListStore) model;
        Gtk.TreeIter i;
        store.append (out i);
        store.set (i, 0, item);
    }

    public new void clear () {
        ((Gtk.ListStore) model).clear ();
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
                    label = ngettext ("%d selected", "%d selected", n_items).printf (n_items);
                }
                menubutton_label.label = label;
            }
        }
    }

    private uint _n_items;
    private Gtk.Label menubutton_label;

    public SelectionMenuButton () {
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
    private bool can_select {
        get {
            return _can_select;
        }

        private set {
            if (_can_select != value) {
                _can_select = value;

                // show the select button only if we are mapped,
                // since we do not want to show it when the geolocation
                // query ends, but we are on another page
                select_button.visible = _can_select && get_mapped ();
            }
        }
    }

    private bool _can_select;
    private ContentStore model;
    private IconView icon_view;
    private Gtk.Button select_button;
    private Gtk.Button cancel_button;
    private SelectionMenuButton selection_menubutton;
    private Gtk.Grid grid;
    private Gtk.Button delete_button;
    private HeaderBar? header_bar;

    construct {
        icon_view = new IconView ();

        var scrolled_window = new Gtk.ScrolledWindow (null, null);
        scrolled_window.add (icon_view);
        scrolled_window.hexpand = true;
        scrolled_window.vexpand = true;
        scrolled_window.halign = Gtk.Align.FILL;
        scrolled_window.valign = Gtk.Align.FILL;

        grid = new Gtk.Grid ();
        grid.attach (scrolled_window, 0, 0, 1, 1);

        var action_bar = new Gtk.ActionBar ();
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
            icon_view.mode = IconView.Mode.NORMAL;
        });

        action_bar.pack_end (delete_button);

        icon_view.notify["mode"].connect (() => {
            if (icon_view.mode == IconView.Mode.SELECTION) {
                action_bar.show ();
            } else if (icon_view.mode == IconView.Mode.NORMAL) {
                action_bar.hide ();
            }
        });

        icon_view.item_activated.connect ((path) => {
            var store = (Gtk.ListStore) icon_view.model;
            Gtk.TreeIter iter;
            if (store.get_iter (out iter, path)) {
                ContentItem? item;
                store.get (iter, 0, out item);
                if (item != null) {
                    item_activated (item);
                }
            }
        });

        add (grid);
        grid.show_all ();
    }

    public signal void item_activated (ContentItem item);

    public void bind_model (ContentStore store) {
        model = store;
        model.items_changed.connect ((position, removed, added) => {
            var first_selectable = model.find ((i) => {
                return i.selectable;
            });

            can_select = first_selectable != null;

            // Just clear and repopulate the GtkTreeModel...
            // it sucks, but there is no easy way to sync to a GListMode
            // and we always have few items.
            icon_view.clear ();
            model.foreach ((item) => {
                icon_view.add_item (item);
            });
        });

        model.selection_changed.connect (() => {
            var n_items = model.get_n_selected ();
            selection_menubutton.n_items = n_items;

            if (n_items != 0) {
                delete_button.sensitive = true;
            } else {
                delete_button.sensitive = false;
            }
        });
    }

    public void select_all () {
        icon_view.mode = IconView.Mode.SELECTION;
        model.select_all ();
    }

    public void unselect_all () {
        model.unselect_all ();
    }

    public bool escape_pressed () {
        if (icon_view.mode == IconView.Mode.SELECTION) {
            icon_view.mode = IconView.Mode.NORMAL;
            return true;
        }
        return false;
    }

    public void set_header_bar (HeaderBar bar) {
        header_bar = bar;

        select_button = new Gtk.Button ();
        var select_button_image = new Gtk.Image.from_icon_name ("object-select-symbolic", Gtk.IconSize.MENU);
        select_button.set_image (select_button_image);
        select_button.valign = Gtk.Align.CENTER;
        select_button.no_show_all = true;
        select_button.clicked.connect (() => {
            icon_view.mode = IconView.Mode.SELECTION;
        });
        header_bar.pack_end (select_button);

        cancel_button = new Gtk.Button.with_label (_("Cancel"));
        cancel_button.no_show_all = true;
        cancel_button.valign = Gtk.Align.CENTER;
        cancel_button.clicked.connect (() => {
            icon_view.mode = IconView.Mode.NORMAL;
        });
        header_bar.pack_end (cancel_button);

        selection_menubutton = new SelectionMenuButton ();

        icon_view.notify["mode"].connect (() => {
            if (icon_view.mode == IconView.Mode.SELECTION) {
                header_bar.mode = HeaderBar.Mode.SELECTION;
            } else if (icon_view.mode == IconView.Mode.NORMAL) {
                // clear current selection
                icon_view.unselect_all ();
                header_bar.mode = HeaderBar.Mode.NORMAL;
            }
        });
    }

    public void update_header_bar () {
        switch (header_bar.mode) {
        case HeaderBar.Mode.SELECTION:
            header_bar.custom_title = selection_menubutton;
            cancel_button.show ();
            break;
        case HeaderBar.Mode.NORMAL:
            select_button.visible = can_select;
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

        return base.draw(cr);
    }

    public virtual void draw_progress (Cairo.Context cr, int center_x, int center_y, int radius) {
    }
}

} // namespace Clocks
