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
    private File? _file;
    public File? file {
        get {
            return _file;
        }
        construct set {
            if (value != null ) {
                // Set the file exactly once, directly or from a URI.
                assert (_file == null);
                _file = value;
            }
        }
    }

    // Own the URI string because File.get_uri() transfers ownership of the
    // string but method getters can't transfer ownership. But at it's all
    // construct properties, we can at least compute it only once.
    private string _uri;
    public string uri {
        get {
            if (_file != null && _uri == null)
                _uri = _file.get_uri ();

            return _uri;
        }
        construct set {
            if (value != null ) {
                // Set the file exactly once, directly or from a URI.
                assert (_file == null);
                _file = File.new_for_uri (value);
            }
        }
    }

    public string label { get; construct set; default = ""; }

    construct {
        // Set the file exactly once, directly or from a URI.
        assert (file != null);
        assert (uri != "");
        if (!file.query_exists ()) {
            critical ("Sound file '%s' not found.", uri);
        }
    }

    public Sound (File? file, string label) {
        Object (file: file, label: label);
    }
}

} // namespace Clocks
