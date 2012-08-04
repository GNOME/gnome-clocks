import datetime, vobject, time

class AlarmItem:
    def __init__(self, name, time, repeat, h, m, p):
        self.name = name
        self.time = time
        self.repeat = repeat
        self.h = h
        self.m = m
        self.p = p

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
        if self.p == 'AM':
            print self.h
            if self.h == 12:
                self.h = 0
            h_end = self.h+1
            m_end = self.m
        elif self.p == 'PM':
            self.h += 12
            h_end = self.h+1
            m_end = self.m
            if self.h == 24:
                self.h = 23
                h_end = 23
                m_end = 59
        else:
            h_end = self.h
            m_end = 59
        alarm.add('dtstart').value = datetime.datetime.combine(datetime.date.today(), datetime.time(self.h, self.m))                      
        alarm.add('dtend').value = datetime.datetime.combine(datetime.date.today(), datetime.time(h_end, m_end))
        alarm.add('rrule').value = 'FREQ=WEEKLY;BYDAY=%s' % ','.join(self.repeat)        
        return alarm        
