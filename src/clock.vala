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

public enum Clocks.PanelId {
    WORLD,
    ALARM,
    STOPWATCH,
    TIMER,
}


public interface Clocks.Clock : GLib.Object {
    public abstract PanelId panel_id { get; protected construct set; }
    public abstract ButtonMode button_mode { get; set; }
    public abstract string? new_label { get; }

    public virtual void activate_new () {
    }

    public virtual bool escape_pressed () {
        return false;
    }
}
