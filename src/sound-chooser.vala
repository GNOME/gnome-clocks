/*
 * Copyright (C) 2025  Adrien Plazas <aplazas@gnome.org>
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

[GtkTemplate (ui = "/org/gnome/clocks/ui/sound-chooser.ui")]
private class SoundChooser : Adw.NavigationPage {
    public ListModel model { get; construct; }
    public Sound silent_sound { get { return silent_row.sound; } }
    public Sound sound { get; set; }

    [GtkChild]
    private unowned SoundChooserRow silent_row;
    [GtkChild]
    private unowned Adw.PreferencesGroup sound_group;

    private Utils.Bell bell;

    public const string SILENT_SOUND_URI = "resource:///org/gnome/clocks/sounds/silent";

    static construct {
        typeof (SoundChooserRow).ensure ();
    }

    construct {
        notify["sound"].connect (() => {
            update ();
        });
        notify["parent"].connect (() => {
            stop_bell ();
            update ();
        });
        hiding.connect (() => {
            stop_bell ();
            update ();
        });
        sound_group.bind_model (model, (item) => {
            var row = new SoundChooserRow ((Sound) item);
            row.activated.connect (row_activated);
            update.connect (() => update_row (row));
            return row;
        });
        update ();
    }

    private void ring_bell () {
        if (sound.uri != SILENT_SOUND_URI) {
            bell = new Utils.Bell (GLib.File.new_for_uri (sound.uri));
            bell.ring ();
        }
    }

    private bool stop_bell () {
        if (bell != null) {
            bell.stop ();
            bell = null;
            return true;
        }
        return false;
    }

    [GtkCallback]
    private void row_activated (Adw.ActionRow row) {
        var sound_chooser_row = row as SoundChooserRow;
        var activated_sound = sound_chooser_row.sound;

        if (sound == activated_sound) {
            // Toggle ringing the already selected sound.
            if (!stop_bell ()) {
                ring_bell ();
            }
            update ();
        } else {
            freeze_notify ();
            sound = activated_sound;

            stop_bell ();
            ring_bell ();
            thaw_notify ();
        }
    }

    private void update_row (SoundChooserRow row) {
        if (row.sound == sound) {
            row.selected = true;
            row.ringing = bell != null;
        } else {
            row.selected = false;
            row.ringing = false;
        }
    }

    private signal void update () {
        update_row (silent_row);
    }
}

} // namespace Clocks
