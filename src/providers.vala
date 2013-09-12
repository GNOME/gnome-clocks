/*
 * Copyright (C) 2013  Evgeny Bobkin <evgen.ibqn@gmail.com>
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
namespace World {

public interface ImageProvider : GLib.Object {
    public virtual Gdk.Pixbuf? get_image (string name) {
        return null;
    }

    public signal void image_updated ();
}

// This is the default fallback provider
public class DefaultProvider : GLib.Object, ImageProvider {
    private static Gdk.Pixbuf? day_image;
    private static Gdk.Pixbuf? night_image;

	public virtual Gdk.Pixbuf? get_image (string name) {
        if (name.has_suffix ("-day")) {
            return day_image;
        } else if (name.has_suffix ("-night")) {
            return night_image;
        }
        return null;
    }

    public DefaultProvider () {
        day_image = Utils.load_image ("day.png");
        night_image =  Utils.load_image ("night.png");
    }
}

public class LocalImageProvider : GLib.Object, ImageProvider {
    private string folder_path;
    private FileMonitor monitor;

    public LocalImageProvider () {
        folder_path = GLib.Path.build_path (GLib.Path.DIR_SEPARATOR_S,
                                            GLib.Environment.get_user_data_dir (),
                                            "gnome-clocks", "city-images");

        File folder = File.new_for_path (folder_path);

        try {
            monitor = folder.monitor_directory (FileMonitorFlags.NONE, null);
            stdout.printf ("Monitoring: %s\n", folder.get_path ());

            monitor.changed.connect ((src, dest, event) => {
                if (dest != null) {
                    stdout.printf ("%s: %s, %s\n", event.to_string (),
                                   src.get_path (), dest.get_path ());
                } else {
                    stdout.printf ("%s: %s\n", event.to_string (), src.get_path ());
                }

                image_updated ();
            });
        } catch (Error err) {
            warning ("Monitoring image files: %s\n", err.message);
        }
    }

    public Gdk.Pixbuf? get_image (string name) {
        Gdk.Pixbuf? image = null;

        try {
            var path = GLib.Path.build_path (GLib.Path.DIR_SEPARATOR_S, folder_path, name + ".jpg");

            image = new Gdk.Pixbuf.from_file (path);
		} catch (Error e) {
            warning ("Loading image file: %s", e.message);
        }

        return image;
    }
}

public class AutomaticImageProvider : GLib.Object, ImageProvider {
	private List<ImageProvider> providers;

    public AutomaticImageProvider () {
		providers = new List<ImageProvider> ();

		providers.prepend (new DefaultProvider ());
		providers.prepend (new LocalImageProvider ());

        foreach (var provider in providers) {
            provider.image_updated.connect (() => {
                image_updated ();
            });
        }
	}

	public virtual Gdk.Pixbuf? get_image (string name) {
		Gdk.Pixbuf? image = null;

		foreach (ImageProvider provider in providers) {
			image = provider.get_image (name);

			if (image != null) {
				break;
			}
		}

		return image;
    }
}

} // namespace World
} // namespace Clocks
