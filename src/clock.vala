/*
 * Copyright (C) 2013  Paolo Borelli <pborelli@gnome.org>
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

public interface Clock : GLib.Object {
    public abstract string label { get; protected construct set; }
    public abstract Toolbar toolbar { get; protected construct set; }

    public virtual void activate_new () {
    }

    public virtual void activate_select_all () {
    }

    public virtual void activate_select_none () {
    }

    public virtual bool escape_pressed () {
        return false;
    }

    public virtual void update_toolbar () {
    }
}

} // namespace Clocks
