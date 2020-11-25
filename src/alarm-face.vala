/*
 * Copyright (C) 2013  Paolo Borelli <pborelli@gnome.org>
 * Copyright (C) 2020  Zander Brown <zbrown@gnome.org>
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
namespace Alarm {

[GtkTemplate (ui = "/org/gnome/clocks/ui/alarm-face.ui")]
public class Face : Gtk.Stack, Clocks.Clock {
    public PanelId panel_id { get; construct set; }
    public ButtonMode button_mode { get; set; default = NEW; }
    // Translators: Tooltip for the + button
    public string? new_label { get; default = _("New Alarm"); }

    private ContentStore alarms;
    private GLib.Settings settings;
    [GtkChild]
    private Gtk.Widget empty_view;
    [GtkChild]
    private Gtk.ListBox listbox;
    [GtkChild]
    private Gtk.ScrolledWindow list_view;

    construct {
        panel_id = ALARM;

        alarms = new ContentStore ();
        settings = new GLib.Settings ("org.gnome.clocks");

        var app = (!) GLib.Application.get_default ();
        var action = (GLib.SimpleAction) app.lookup_action ("stop-alarm");
        action.activate.connect ((action, param) => {
            var a = alarms.find ((a) => {
                return ((Item) a).id == (string) param;
            });

            if (a != null) {
                ((Item) a).stop ();
            }
        });

        action = (GLib.SimpleAction) app.lookup_action ("snooze-alarm");
        action.activate.connect ((action, param) => {
            var a = alarms.find ((a) => {
                return ((Item) a).id == (string) param;
            });

            if (a != null) {
                ((Item) a).snooze ();
            }
        });

        listbox.bind_model (alarms, (item) => {
            item.notify["state"].connect (save);
            return new Row ((Item) item, this);
        });

        listbox.row_activated.connect ((row) => {
           var alarm = ((Row) row).alarm;
           this.edit (alarm);
        });

        load ();

        alarms.items_changed.connect ((position, removed, added) => {
            save ();
            reset_view ();
        });

        reset_view ();

        // Start ticking...
        Utils.WallClock.get_default ().tick.connect (() => {
            alarms.foreach ((i) => {
                var a = (Item)i;
                if (a.tick ()) {
                    if (a.state == Item.State.RINGING) {
                        ring (a);
                    }
                }
            });
        });
    }

    internal signal void ring (Item item);

    private void load () {
        alarms.deserialize (settings.get_value ("alarms"), Item.deserialize);
    }

    private void save () {
        settings.set_value ("alarms", alarms.serialize ());
    }

    internal void edit (Item alarm) {
        var dialog = new SetupDialog ((Gtk.Window) get_toplevel (), alarm, alarms, true);

        dialog.response.connect ((dialog, response) => {
            if (response == Gtk.ResponseType.OK) {
                ((SetupDialog) dialog).apply_to_alarm ();
                save ();
            } else if (response == DELETE_ALARM) {
                alarms.delete_item (alarm);
                save ();
            }
            dialog.destroy ();
        });
        dialog.show ();
    }

    internal void delete (Item alarm) {
        alarms.delete_item (alarm);
        save ();
    }

    private void reset_view () {
        visible_child = alarms.get_n_items () == 0 ? empty_view : list_view;
    }

    public void activate_new () {
        var wc = Utils.WallClock.get_default ();
        var alarm = new Item (wc.date_time.get_hour (), wc.date_time.get_minute ());
        var dialog = new SetupDialog ((Gtk.Window) get_toplevel (), alarm, alarms);

        dialog.response.connect ((dialog, response) => {
          // Enable the newly created alarm
          alarm.active = true;

            if (response == Gtk.ResponseType.OK) {
                ((SetupDialog) dialog).apply_to_alarm ();
                alarms.add (alarm);
                save ();
            }
            dialog.destroy ();
        });
        dialog.show ();
    }
}

} // namespace Alarm
} // namespace Clocks
