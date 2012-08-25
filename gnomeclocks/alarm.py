# Copyright (c) 2011-2012 Collabora, Ltd.
#
# Gnome Clocks is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by the
# Free Software Foundation; either version 2 of the License, or (at your
# option) any later version.
#
# Gnome Clocks is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public License along
# with Gnome Clocks; if not, write to the Free Software Foundation,
# Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#
# Author: Seif Lotfy <seif.lotfy@collabora.co.uk>

import os
from datetime import datetime
import vobject

from utils import Dirs, SystemSettings


class ICSHandler():
    def __init__(self):
        self.ics_file = os.path.join(Dirs.get_user_data_dir(), "alarms.ics")

    def add_vevent(self, vobj):
        with open(self.ics_file, 'r+') as ics:
            vcal = vobject.readOne(ics)
            vcal.add(vobj)
            ics.seek(0)
            vcal.serialize(ics)

    def remove_vevents(self, uids):
        with open(self.ics_file, 'r+') as ics:
            vcal = vobject.readOne(ics)
            v_set = []
            for v in vcal.components():
                if v.uid.value in uids:
                    v_set.append(v)
            for v in v_set:
                vcal.remove(v)
            ics.seek(0)
            vcal.serialize(ics)

    def load_vevents(self):
        alarms = []
        if os.path.exists(self.ics_file):
            with open(self.ics_file, 'r') as ics:
                vcal = vobject.readOne(ics.read())
                for item in vcal.components():
                    alarms.append(item)
        else:
            self.generate_ics_file()
        return alarms

    def generate_ics_file(self):
        vcal = vobject.iCalendar()
        ics = open(self.ics_file, 'w')
        ics.write(vcal.serialize())
        ics.close()

    def edit_alarm(self, alarm):
        with open(self.ics_file, 'r+') as ics:
            vcal = vobject.readOne(ics.read())
        for event in vcal.vevent_list:
            if event.uid.value == alarm.uid:
                #FIXME: Update instead of remove and add
                self.remove_vevents((alarm.uid,))
                self.add_vevent(alarm.get_vevent())


class AlarmItem:
    def __init__(self, name=None, repeat=None, h=None, m=None, p=None):
        self.name = name
        self.repeat = repeat
        self.vevent = None
        self.uid = None
        self.h = h
        self.m = m
        self.p = p
        if not h == None and not m == None:
            if p:
                t = datetime.strptime("%02i:%02i %s" % (h, m, p), "%H:%M %p")
            else:
                t = datetime.strptime("%02i:%02i" % (h, m), "%H:%M")
            self.time = datetime.combine(datetime.today(), t.time())
            self.expired = datetime.now() > self.time
        else:
            self.time = None
            self.expired = True

    def new_from_vevent(self, vevent):
        self.vevent = vevent
        self.name = vevent.summary.value
        self.time = vevent.dtstart.value
        self.uid = vevent.uid.value
        if vevent.rrule.value == 'FREQ=DAILY;':
            self.repeat = ['FR', 'MO', 'SA', 'SU', 'TH', 'TU', 'WE']
        else:
            self.repeat = vevent.rrule.value[19:].split(',')
        self.expired = datetime.now() > self.time

    def get_time_as_string(self):
        if SystemSettings.get_clock_format() == "12h":
            return self.time.strftime("%I:%M %p")
        else:
            return self.time.strftime("%H:%M")

    def set_alarm_name(self, name):
        self.name = name

    def get_alarm_name(self):
        return self.name

    def set_alarm_repeat(self, repeat):
        self.repeat = repeat

    def get_alarm_repeat(self):
        return self.repeat

    def get_alarm_repeat_string(self):
        # lists only compare the same if corresponing elements are the same
        # we form self.repeat by random appending
        # sorted(list of days)
        sorted_repeat = sorted(self.repeat)
        if sorted_repeat == ['FR', 'MO', 'SA', 'SU', 'TH', 'TU', 'WE']:
            return "Every day"
        elif sorted_repeat == ['FR', 'MO', 'TH', 'TU', 'WE']:
            return "Weekdays"
        elif len(sorted_repeat) == 0:
            return None
        else:
            repeat_string = ""
            if 'MO' in self.repeat:
                repeat_string += 'Mon, '
            if 'TU' in self.repeat:
                repeat_string += 'Tue, '
            if 'WE' in self.repeat:
                repeat_string += 'Wed, '
            if 'TH' in self.repeat:
                repeat_string += 'Thu, '
            if 'FR' in self.repeat:
                repeat_string += 'Fri, '
            if 'SA' in self.repeat:
                repeat_string += 'Sat, '
            if 'SU' in self.repeat:
                repeat_string += 'Sun, '
            return repeat_string[:-2]

    def get_vevent(self):
        if self.vevent:
            return self.vevent

        self.vevent = vevent = vobject.newFromBehavior('vevent')
        vevent.add('summary').value = self.name
        vevent.add('dtstart').value = self.time
        vevent.add('dtend').value = self.time
        if len(self.repeat) == 0:
            vevent.add('rrule').value = 'FREQ=DAILY;'
        else:
            vevent.add('rrule').value = 'FREQ=WEEKLY;BYDAY=%s' %\
            ','.join(self.repeat)
        return vevent

    # FIXME: this is not a really good way, we assume each alarm
    # can ring only once while the program is running
    def check_expired(self):
        if self.expired:
            return False
        self.expired = datetime.now() > self.time
        return self.expired
