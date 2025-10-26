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
        var alarms_dir = File.new_build_filename (Config.DATADIR, "sounds/gnome/default/alarms");

        store = new ListStore (typeof (Sound));

        // FIXME GtkMediaFile doesn't support gapless looping, causing audible
        // clicks in alarm sounds. This is caused by GstPlay not supporting
        // gapless chainup or looping.
        // See https://gitlab.freedesktop.org/gstreamer/gstreamer/-/issues/1200
        // for more information.

        // Translators: An alarm sound name
        store.append (new Sound (build_default_file (), _("Beep-Beep")));
        // Translators: An alarm sound name
        store.append (new Sound (alarms_dir.get_child ("bird.oga"), _("Bird")));
        // Translators: An alarm sound name
        store.append (new Sound (alarms_dir.get_child ("bonfire.oga"), _("Bonfire")));
        // Translators: An alarm sound name
        store.append (new Sound (alarms_dir.get_child ("boudoir.oga"), _("Boudoir")));
        // Translators: An alarm sound name
        store.append (new Sound (alarms_dir.get_child ("bouncing.oga"), _("Bouncing")));
        // Translators: An alarm sound name
        store.append (new Sound (alarms_dir.get_child ("cautious-steps.oga"), _("Cautious Steps")));
        // Translators: An alarm sound name
        store.append (new Sound (alarms_dir.get_child ("chirping.oga"), _("Chirping")));
        // Translators: An alarm sound name
        store.append (new Sound (alarms_dir.get_child ("class-act.oga"), _("Class Act")));
        // Translators: An alarm sound name
        store.append (new Sound (alarms_dir.get_child ("crossing-bell.oga"), _("Crossing Bell")));
        // Translators: An alarm sound name
        store.append (new Sound (alarms_dir.get_child ("daydreaming.oga"), _("Daydreaming")));
        // Translators: An alarm sound name
        store.append (new Sound (alarms_dir.get_child ("digitone.oga"), _("Digitone")));
        // Translators: An alarm sound name
        store.append (new Sound (alarms_dir.get_child ("enchanting.oga"), _("Enchanting")));
        // Translators: An alarm sound name
        store.append (new Sound (alarms_dir.get_child ("glass-bell.oga"), _("Glass Bell")));
        // Translators: An alarm sound name
        store.append (new Sound (alarms_dir.get_child ("guitar.oga"), _("Guitar")));
        // Translators: An alarm sound name
        store.append (new Sound (alarms_dir.get_child ("jolly.oga"), _("Jolly")));
        // Translators: An alarm sound name
        store.append (new Sound (alarms_dir.get_child ("mystery.oga"), _("Mystery")));
        // Translators: An alarm sound name
        store.append (new Sound (alarms_dir.get_child ("ping-ping.oga"), _("Ping Ping")));
        // Translators: An alarm sound name
        store.append (new Sound (alarms_dir.get_child ("school-bell.oga"), _("School Bell")));
        // Translators: An alarm sound name
        store.append (new Sound (alarms_dir.get_child ("sonar.oga"), _("Sonar")));
        // Translators: An alarm sound name
        store.append (new Sound (alarms_dir.get_child ("sparkling.oga"), _("Sparkling")));
        // Translators: An alarm sound name
        store.append (new Sound (alarms_dir.get_child ("tingling.oga"), _("Tingling")));
        // Translators: An alarm sound name
        store.append (new Sound (alarms_dir.get_child ("toys.oga"), _("Toys")));

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
