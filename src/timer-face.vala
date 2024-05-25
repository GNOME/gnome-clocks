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

[GtkTemplate (ui = "/org/gnome/clocks/ui/timer-face.ui")]
public class Face : Adw.Bin, Clocks.Clock {
    private Setup timer_setup;
    [GtkChild]
    private unowned Gtk.ListBox timers_list;
    [GtkChild]
    private unowned Gtk.Button start_button;
    [GtkChild]
    private unowned Gtk.Stack stack;
    [GtkChild]
    private unowned Adw.Bin timer_bin;

    public PanelId panel_id { get; construct set; }
    public ButtonMode button_mode { get; set; default = NONE; }
    public bool is_running { get; set; default = false; }
    // Translators: Tooltip for the + button
    public string? new_label { get; default = _("New Timer"); }

    private ContentStore timers;
    private Gtk.SortListModel sorted_timers;
    private GLib.Settings settings;
    private Utils.Bell bell;
    private GLib.Notification notification;

    construct {
        panel_id = TIMER;
        timer_setup = new Setup ();

        settings = new GLib.Settings ("org.gnome.clocks");
        timers = new ContentStore ();

        sorted_timers = new Gtk.SortListModel (
            timers,
            new Gtk.CustomSorter ((a, b) => Item.compare ((Item) a, (Item) b))
        );

        timers_list.bind_model (sorted_timers, (timer) => {
            var row = new Row ((Item) timer);
            row.deleted.connect (() => remove_timer ((Item) timer));
            row.edited.connect (() => save ());
            ((Item)timer).ring.connect (() => ring ());
            ((Item)timer).notify["state"].connect (() => {
                this.is_running = this.get_total_active_timers () != 0;
            });
            return row;
        });

        timers.items_changed.connect ( (added, removed, position) => {
            if (this.timers.get_n_items () > 0) {
                stack.visible_child_name = "timers";
                this.button_mode = NEW;
            } else {
                stack.visible_child_name = "empty";
                this.button_mode = NONE;
            }
            save ();
        });

        bell = new Utils.Bell (GLib.File.new_for_uri ("resource://org/gnome/clocks/sounds/complete.oga"));
        notification = new GLib.Notification (_("Time is up!"));
        notification.set_body (_("Timer countdown finished"));
        notification.set_priority (HIGH);

        timer_bin.child = timer_setup;
        stack.set_visible_child_name ("empty");

        start_button.set_sensitive (false);
        timer_setup.duration_changed.connect ((duration) => {
            start_button.set_sensitive (duration != 0);
        });
        timer_setup.start_timer.connect (() => {
            var timer = this.timer_setup.get_timer ();
            this.timers.add (timer);
            connect_item (timer);

            timer.start ();
        });
        start_button.clicked.connect (() => {
            var timer = this.timer_setup.get_timer ();
            this.timers.add (timer);
            connect_item (timer);

            timer.start ();
        });
        load ();
    }

    private int get_total_active_timers () {
        var total_items = 0;
        this.timers.foreach ((timer) => {
            if (((Item)timer).state == Item.State.RUNNING) {
                total_items += 1;
            }
        });
        return total_items;
    }

    private void remove_timer (Item item) {
        timers.remove (item);
    }

    public void activate_new () {
        var dialog = new SetupDialog ();
        dialog.done.connect ((dialog) => {
            var timer = ((SetupDialog) dialog).timer_setup.get_timer ();
            this.timers.add (timer);
            connect_item (timer);
            timer.start ();
            dialog.close ();
        });
        dialog.present (get_root ());
    }

    private void connect_item (Item item) {
        item.notify["hours"].connect (() => {
            sorted_timers.sorter.changed (DIFFERENT);
        });
        item.notify["minutes"].connect (() => {
            sorted_timers.sorter.changed (DIFFERENT);
        });
        item.notify["seconds"].connect (() => {
            sorted_timers.sorter.changed (DIFFERENT);
        });
        item.notify["state"].connect (() => {
            sorted_timers.sorter.changed (DIFFERENT);
        });
    }

    private void load () {
        timers.deserialize (settings.get_value ("timers"), Item.deserialize);

        timers.foreach (item => connect_item ((Item) item));
    }

    private void save () {
        settings.set_value ("timers", timers.serialize ());
    }

    public virtual signal void ring () {
        var app = (Clocks.Application) GLib.Application.get_default ();
        app.send_notification ("timer-is-up", notification);
        bell.ring_once ();
    }

    public override bool grab_focus () {
        if (timers.get_n_items () == 0) {
            start_button.grab_focus ();
            return true;
        }

        return false;
    }

    public bool escape_pressed () {
        var res = false;
        this.timers.foreach ((item) => {
                var timer = (Item) item;
                if (timer.state == Item.State.RUNNING) {
                    timer.pause ();
                    res = true;
                }
            });
        return res;
    }
}

} // namespace Timer
} // namespace Clocks
