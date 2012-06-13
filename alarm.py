#WEEKDAYS:
day1 = "day1"
day2 = "day2"
day3 = "day3"
day4 = "day4"
day5 = "day5"
day6 = "day6"
day7 = "day7"

class AlarmItem:
    def __init__(self, name, time, repeat):
        self.n = name
        self.t = time
        self.r = repeat

    def set_alarm_time(self, time):
        self.t = time 
        
    def get_alarm_time(self):
        return self.t
        
    def set_alarm_name(self, name):
        self.n = name
    
    def get_alarm_name(self):
        return self.n
        
    def set_alarm_repeat(self, repeat):
        self.r = repeat

    def get_alarm_repeat(self):
	return self.r
