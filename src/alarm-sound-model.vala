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
namespace Alarm {

private class SoundModel : ListModel, Object {
    ListStore store;

    construct {
        store = new ListStore (typeof (Sound));

        // Translators: An alarm sound name
        store.append (new Sound (build_default_file (), _("Beep-Beep")));

        store.sort ((a, b) => {
            var sound_a = a as Sound;
            var sound_b = b as Sound;
            return strcmp (sound_a.label, sound_b.label);
        });
    }

    public static File build_default_file () {
        return File.new_for_uri ("resource:///org/gnome/clocks/sounds/alarms/beep-beep.oga");
    }

    public Type get_item_type () {
        return store.get_item_type ();
    }

    public uint get_n_items () {
        return store.get_n_items ();
    }

    public Object? get_item (uint n) {
        return store.get_item (n);
    }

    public Sound? find_by_file (File file) {
        var n_items = store.get_n_items ();
        for (uint i = 0; i < n_items; i++) {
            var sound = store.get_item (i) as Sound;
            if (sound != null && sound.file != null && sound.file.equal (file)) {
                return sound;
            }
        }
        return null;
    }
}

} // namespace Alarm
} // namespace Clocks
