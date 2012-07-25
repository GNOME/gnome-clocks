import datetime, vobject, time

class AlarmItem:
    def __init__(self, name, time, repeat, h, m):
        self.name = name
        self.time = time
        self.repeat = repeat
        self.h = h
        self.m = m

    def set_alarm_time(self, time):
        self.time = time 
        
    def get_alarm_time(self):
        return self.time
        
    def set_alarm_name(self, name):
        self.name = name
    
    def get_alarm_name(self):
        return self.name
        
    def set_alarm_repeat(self, repeat):
        self.repeat = repeat

    def get_alarm_repeat(self):
        return self.repeat
    
    def get_vobject(self):                
        alarm = vobject.newFromBehavior('vevent')            
        alarm.add('summary').value = self.name                
        #t = datetime.datetime.utcfromtimestamp(self.time)
        alarm.add('dtstart').value = datetime.datetime.combine(datetime.date.today(), datetime.time(self.h, self.m))        
        alarm.add('dtend').value = datetime.datetime.combine(datetime.date.today(), datetime.time(self.h+1, self.m))
        alarm.add('rrule').value = 'FREQ=WEEKLY;BYDAY=%s' % ','.join(self.repeat)
        alarm.add('action').value = 'audio'
        alarm.add('attach').value = '/usr/share/sounds/gnome/default/alerts/glass.ogg'
        return alarm        
