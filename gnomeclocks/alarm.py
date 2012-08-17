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

import datetime
import vobject
import os


class ICSHandler():
    def __init__(self):
        self.ics_file = 'alarms.ics'

    def add_vevent(self, vobj):
        with open(self.ics_file, 'r+') as ics:
            content = ics.read()
            ics.seek(0)
            vcal = vobject.readOne(content)
            vcal.add(vobj)
            ics.write(vcal.serialize())

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
        ics = open('alarms.ics', 'w')
        ics.write(vcal.serialize())
        ics.close()

    def delete_alarm(self, alarm_uid):
        # TODO: Add alarm deletion support
        pass

    def edit_alarm(self, alarm_uid, new_name=None, new_hour=None,
                   new_mins=None, new_p=None, new_repeat=None):
        with open(self.ics_file, 'r+') as ics:
            vcal = vobject.readOne(ics.read())
        for event in vcal.vevent_list:
            if event.uid.value == alarm_uid:
                if new_name:
                    del event.summary
                    event.add('summary').value = new_name


class AlarmItem:
    def __init__(self, name=None, repeat=None, h=None, m=None, p=None):
        self.name = name
        self.repeat = repeat
        self.vevent = None
        self.uid = None
        self.h = h
        self.m = m
        self.p = p

    def new_from_vevent(self, vevent):
        self.name = vevent.summary.value
        self.time = vevent.dtstart.value
        self.h = int(self.time.strftime("%H"))
        self.m = int(self.time.strftime("%M"))
        self.p = self.time.strftime("%p")
        self.uid = vevent.uid.value

    def set_alarm_time(self, h, m, p):
        self.h = h
        self.m = m
        self.p = p

    def get_alarm_time(self):
        time = {}
        time['h'] = self.h
        time['m'] = self.m
        time['p'] = self.p
        return self.time

    def get_time_12h_as_string(self):
        if self.p == 'AM' or self.p == 'PM':
            if self.h == 12 or self.h == 0:
                h = 12
            else:
                h = self.h - 12
        else:
            h = self.h
        return "%2i:%02i %s" % (h, self.m, self.p)

    def get_time_24h_as_string(self):
        if self.p == 'AM' or self.p == 'PM':
            h = self.h + 12
            if h == 24:
                h = 12
        else:
            h = self.h
        return "%2i:%02i" % (h, self.m)

    def set_alarm_name(self, name):
        self.name = name

    def get_alarm_name(self):
        return self.name

    def set_alarm_repeat(self, repeat):
        self.repeat = repeat

    def get_alarm_repeat(self):
        return self.repeat

    def get_uid(self):
        return self.vevent.uid.value

    def get_vevent(self):
        self.vevent = vevent = vobject.newFromBehavior('vevent')
        vevent.add('summary').value = self.name
        h = self.h
        m = self.m
        if self.p == "PM":
            h = self.h + 12
            if h == 24:
                h = 12
        elif self.p == "AM":
            if h == 12:
                h = 0
        vevent.add('dtstart').value =\
            datetime.datetime.combine(datetime.date.today(),
                                      datetime.time(h, m))
        vevent.add('dtend').value =\
            datetime.datetime.combine(datetime.date.today(),
                                      datetime.time(h, 59))
        if len(self.repeat) == 0:
            vevent.add('rrule').value = 'FREQ=DAILY;'
        else:
            vevent.add('rrule').value = 'FREQ=WEEKLY;BYDAY=%s' %\
            ','.join(self.repeat)
        return vevent
