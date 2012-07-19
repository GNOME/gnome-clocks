import vobject, os

class AlarmsHandler():
    def __init__(self):
        self.ics_file = 'alarms.ics'
        
    def add_alarm(self, vobj):
        ics = open(self.ics_file, 'r+')        
        content = ics.read()        
        ics.seek(0)
        vcal = vobject.readOne(content)                  
        vcal.add(vobj)        
        ics.write(vcal.serialize())      
        ics.close()
                
    def load_alarms(self):                
        alarms = [] 
        if os.path.exists(self.ics_file):
            ics = open(self.ics_file, 'r')        
            ics.seek(0)            
            vcal = vobject.readOne(ics.read())          
            for item in vcal.components():            
                alarms.append(item)                    
            ics.close()                           
        else:
            self.generate_ics_file()
        return alarms
        
    def generate_ics_file(self):
        vcal = vobject.iCalendar()
        ics = open('alarms.ics', 'w')      
        ics.write(vcal.serialize())
        ics.close()  
        
        
    def delete_alarm(self, smth_special_about_alarm):
        ics = open('alarms.ics', 'r+')
        data = ics.read()
        ics.close()
