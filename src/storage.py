"""
 Copyright (c) 2012 Collabora, Ltd.

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
import pickle
from xdg import BaseDirectory
from gi.repository import GWeather

DATA_PATH = BaseDirectory.save_data_path("clocks") + "/clocks"

class Location ():
    def __init__ (self, location):
        self._id = location.get_city_name ()
        self._location = location

    @property
    def id(self):
        return self._id

    @property
    def location(self):
        return self._location

class WorldClockStorage ():
    def __init__ (self):
        world = GWeather.Location.new_world(True)
        self.searchEntry = GWeather.LocationEntry.new(world)
        self.searchEntry.show_all ()
        self.locations_dump = ""
        pass

    def save_clocks (self, locations):
        self.locations_dump = locations = "|".join([location.id + "---" + location.location.get_code () for location in locations])
        f = open (DATA_PATH, "wb")
        pickle.dump (locations, f)
        f.close ()

    def load_clocks (self):
        try:
          f = open (DATA_PATH, "rb")
          self.locations_dump = locations = pickle.load (f)
          f.close ()
          locations = locations.split ("|")
          clocks = []
          for location in locations:
              loc = location.split ("---")
              if self.searchEntry.set_city (loc[0], loc[1]):
                  loc = self.searchEntry.get_location ()
                  loc = Location (self.searchEntry.get_location ())
                  clocks.append (loc)
          return clocks
        except Exception, e:
          print "--", e
          return []
          
    def delete_all_clocks(self):
        f = open(DATA_PATH, "w")
        f.write("")
        f.close()

worldclockstorage = WorldClockStorage ()
worldclockstorage.delete_all_clocks()
