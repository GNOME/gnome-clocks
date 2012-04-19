"""
 Copyright (c) 2011 Collabora, Ltd.

 Gnome Clocks is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by the
 Free Software Foundation; either version 2 of the License, or (at your
 option) any later version.

 Gnome Clocks is distributed in the hope that it will be useful, but
 WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
 or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 for more details.
 
 You should have received a copy of the GNU General Public License along
 with Gnome Documents; if not, write to the Free Software Foundation,
 Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 
 Author: Seif Lotfy <seif.lotfy@collabora.co.uk>
"""

import os

TIMEZONE_DB_PATH = "/usr/share/zoneinfo/zone.tab"
if not os.path.exists (TIMEZONE_DB_PATH):
    TIMEZONE_DB_PATH = "/usr/share/lib/zoneinfo/tab/zone_sun.tab"
    
TIMEZONE_HASH = {}

def populate_timezone_hash ():
    global TIMEZONE_HASH
    TIMEZONE_HASH = {}
    f = open (TIMEZONE_DB_PATH, "r")
    for line in f.readlines():
        line = line.strip()
        if not line.startswith("#"):
            line = line.split("\t")
            timezone = line[2].split("/")[0]
            if not TIMEZONE_HASH.has_key(timezone):
                TIMEZONE_HASH[timezone] = {}
            coordinates = []
            
            x = ""
            y = ""
            temp = ""
            for i, char in enumerate(line[1]):
                if i != 0 and char in ("+", "-"):
                        x = int(temp)
                        temp = ""
                temp += char
            y = int(temp)
            
            TIMEZONE_HASH[timezone][line[2].split(timezone+"/")[1]] = (x, y)

populate_timezone_hash()

