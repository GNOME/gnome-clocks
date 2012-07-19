import datetime, vobject, time

class AlarmItem:
    def __init__(self, name, time, repeat):
        self.name = name
        self.time = time
        self.repeat = repeat

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
        alarm.add('title').value = self.name        
        alarm.add('dtstart').value = datetime.datetime.utcnow()        
        t =  datetime.datetime.utcfromtimestamp(self.time)
        alarm.add('dtend').value = t
        alarm.add('rrule').value = 'FREQ=WEEKLY;BYDAY=%s' % ','.join(self.repeat)
        #alarm.add('enddate').value =       
        #alarm.add('repeat').value = '4' #self.repeat
        #alarm.add('duration').value = '15M'        
        #date = datetime.date(datetime.date.today())
        #print date
        #alarm.add('trigger')#.value = datetime.datetime.utcnow() #fromtimestamp(self.time)
        #datetime.datetime.combine(datetime.date.today(), self.time) #Convert self.time to datetime
        alarm.add('action').value = 'audio'
        alarm.add('attach').value = '/usr/share/sounds/gnome/default/alerts/glass.ogg'
        return alarm        
