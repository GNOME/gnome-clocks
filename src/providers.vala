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

    public signal void image_updated (string name);
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

        if (!folder.query_exists ()) {
            try {
                folder.make_directory_with_parents ();
            } catch (Error e) {
                warning ("Could not create a city-images directory: %s", e.message);
            }
        }

        try {
            monitor = folder.monitor_directory (FileMonitorFlags.NONE, null);

            monitor.changed.connect ((src, dest, event) => {
                image_updated (src.get_path ());
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
            // warning ("Loading image file: %s", e.message);
            image = null;
        }

        return image;
    }
}

private class FlickrClient : GLib.Object {
    private static const string api_key = "8fe23980339fd51887815d106d3d3498";
    private static const string url = "http://www.flickr.com/groups/gnome-clocks/";

    private Soup.SessionAsync session;
    private string query_message;

    public string server { get; set; }
    public string group_id { get; set; default = null; }

    public FlickrClient () {
        server = "http://api.flickr.com/services/rest/?format=json&nojsoncallback=1";
        query_message = @"$server&api_key=$api_key";

        session = new Soup.SessionAsync ();
        session.use_thread_context = true;
    }

    private async Json.Object? get_root_object (string message) {
        GLib.InputStream stream;

        string msg = query_message + message;
        var query = new Soup.Message ("GET", msg);

        try {
            stream = yield session.send_async (query);
        } catch (Error e) {
            warning ("Unable to sent message: %s", e.message);
            return null;
        }

        var parser = new Json.Parser ();

        try {
            yield parser.load_from_stream_async (stream);
        } catch (Error e) {
            warning ("Failed to load data from stream: %s", e.message);
            return null;
        }

        var root_object = parser.get_root ().get_object ();

        if (root_object.has_member ("stat")) {
            string stat = root_object.get_string_member ("stat");

            if (stat != "ok") {
                warning ("Response from the server contains an error");
                return null;
            }
        }

        return root_object;
    }

    public async void seek_group_id () {
        string msg = @"&method=flickr.urls.lookupGroup&url=$url";

        var object = yield get_root_object (msg);

        if (object == null) {
            return;
        }

        if (object.has_member ("group")) {
            var group = object.get_object_member ("group");
            if (group.has_member ("id")) {
                group_id = group.get_string_member ("id");
            }
        }
    }

    public async string? seek_image_id (string name) {
        string msg = @"&method=flickr.groups.pools.getPhotos&group_id=$group_id";

        var object = yield get_root_object (msg);

        if (object == null) {
            return null;
        }

        if (object.has_member ("photos")) {
            var photos = object.get_object_member ("photos");
            var node_list = photos.get_array_member ("photo").get_elements ();

            foreach (var node in node_list) {
                var photo = node.get_object ();
                string title = photo.get_string_member ("title");
                //stdout.printf (@"$title\n");
                if (name == title) {
                    string image_id = photo.get_string_member ("id");
                    return image_id;
                }
            }
        }
        return null;
    }

    public async string? seek_image_uri (string image_id) {
        string msg = @"&method=flickr.photos.getSizes&photo_id=$image_id";

        var object = yield get_root_object (msg);

        if (object == null) {
            return null;
        }

        if (object.has_member ("sizes")) {
            var sizes = object.get_object_member ("sizes");
            var node_list = sizes.get_array_member ("size").get_elements ();

            foreach (var node in node_list) {
                var image = node.get_object ();
                string label = image.get_string_member ("label");
                //stdout.printf (@"$label\n");
                if (label == "Original") {
                    string image_url = image.get_string_member ("source");
                    return image_url;
                }
            }
        }
        return null;
    }
}

public class FlickrImageProvider : GLib.Object, ImageProvider {
    private string folder_path;
    private FlickrClient flickr_client;

    public FlickrImageProvider () {
        folder_path = GLib.Path.build_path (GLib.Path.DIR_SEPARATOR_S,
                                            GLib.Environment.get_user_data_dir (),
                                            "gnome-clocks", "city-images", "flickr");

        File folder = File.new_for_path (folder_path);

        if (!folder.query_exists ()) {
            try {
                folder.make_directory_with_parents ();
            } catch (Error e) {
                warning ("Could not create a flickr directory: %s", e.message);
            }
        }

        flickr_client = new FlickrClient ();
    }

    public Gdk.Pixbuf? get_image (string name) {
        Gdk.Pixbuf? image = null;

        try {
            var path = GLib.Path.build_path (GLib.Path.DIR_SEPARATOR_S, folder_path, name + ".jpg");

            image = new Gdk.Pixbuf.from_file (path);
        } catch (Error e) {
            image = null;

            fetch_image.begin (name, (obj, res) => {
                fetch_image.end (res);
            });
        }

        return image;
    }

    private async void fetch_image (string name) {
        if (flickr_client.group_id == null) {
            yield flickr_client.seek_group_id ();
        }

        string? image_id = yield flickr_client.seek_image_id (name);

        if (image_id == null) {
            //warning (@"Could not get image id for $name.");
            return;
        }

        string? image_uri = yield flickr_client.seek_image_uri (image_id);

        if (image_uri == null) {
            warning (@"Could not get image uri for $name.");
            return;
        }

        yield download_image (image_uri, name);
    }

    private async void download_image (string uri, string name) {
        var target_path = GLib.Path.build_path (GLib.Path.DIR_SEPARATOR_S,
                                                folder_path,
                                                name + ".jpg");
        var source = File.new_for_uri (uri);
        var target = File.new_for_path (target_path);

        try {
            yield source.copy_async (target, FileCopyFlags.OVERWRITE);
        } catch (Error e) {
            warning ("Copying an image has failed: %s", e.message);
            return;
        }

        image_updated (name);
    }
}

public class AutomaticImageProvider : GLib.Object, ImageProvider {
    private List<ImageProvider> providers;

    public AutomaticImageProvider () {
        providers = new List<ImageProvider> ();

        providers.prepend (new DefaultProvider ());
        providers.prepend (new FlickrImageProvider ());
        providers.prepend (new LocalImageProvider ());

        foreach (var provider in providers) {
            provider.image_updated.connect ((name) => {
                image_updated (name);
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
