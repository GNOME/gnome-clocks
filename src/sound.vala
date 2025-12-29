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

private class Sound : GLib.Object {
    public File? file { get; construct; }
    public string uri { get; construct; }
    public string label { get; construct; default = ""; }

    construct {
        assert ((file != null) ^ (uri != null));

        if (file != null) {
            uri = file.get_uri ();
        } else {
            file = File.new_for_uri (uri);
        }

        if (!file.query_exists ()) {
            critical ("Sound file '%s' not found.", uri);
        }
    }

    public Sound (File? file, string label) {
        Object (file: file, label: label);
    }
}

} // namespace Clocks
