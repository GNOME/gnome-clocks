/*
 * Copyright (C) 2018  Canonical Ltd
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
namespace Systemd {

struct Property {
    public string name;
    public GLib.Variant value;
}

struct Aux {
    public string name;
    public Property[] value;
}

[DBus (name="org.freedesktop.systemd1.Manager")]
interface SystemdManager : Object {
    /* StartTransientUnit(in  s name,
                          in  s mode,
                          in  a(sv) properties,
                          in  a(sa(sv)) aux,
                          out o job); */
    public abstract GLib.ObjectPath start_transient_unit (string name,
                                                          string mode,
                                                          Property[] properties,
                                                          Aux[] aux) throws IOError;

    /* GetUnit(in  s name,
               out o unit); */
    public abstract GLib.ObjectPath get_unit (string name) throws IOError;
}

[DBus (name="org.freedesktop.systemd1.Unit")]
interface SystemdUnit : Object {
    /* Stop(in  s mode,
            out o job); */
    public abstract GLib.ObjectPath stop (string mode) throws IOError;
}

} // namespace Clocks
} // namespace Utils
