ARDUINO_USB = '/dev/tty.usbserial'
CITY_NAME   = "Cracow,PL"

import serial, json, requests, os.path, time;
from datetime import datetime, timedelta;
#arduino = serial.Serial(ARDUINO_USB, 9600)

ARDUINO_START_SYNC = 0;
ARDUINO_WEATHER    = 2;
ARDUINO_TIME       = 3;
ARDUINO_END_SYNC   = 1;

#api.openweathermap.org/data/2.5/weather?q=Cracow,PL&units=metric
def upload(command, message=None):
  print "Uploading to arduino: "+ str(command)
  if not message is None:
    if isinstance(message, list):
      for m in message:
        print "message "+ str(m)
    else:
      print "message "+ str(message)
  pass

def download_weather_file(cache_file):
  print "Downloading weather file into: " + cache_file
  resp = requests.get(url="http://api.openweathermap.org/data/2.5/weather", params = dict( q=CITY_NAME, units = "metric" ))

  file = open(cache_file, 'w')
  file.write(resp.text)
  file.close()

def get_weather():
  cache_file = "/tmp/weather_cache_"+CITY_NAME+".json"

  if not os.path.isfile(cache_file) or datetime.fromtimestamp(os.path.getctime(cache_file)) < datetime.now() - timedelta(minutes=30):
    download_weather_file(cache_file)

  file = open(cache_file, 'r')
  data = json.loads(file.read())

  if data['cod'] == 200:
    return data
  else:
    return False

def upload_time():
  upload(ARDUINO_TIME, int(time.time()))

def upload_weather_info():
  current_weather = get_weather()
  if current_weather:
    current_temperature = current_weather['main']['temp']
    print "Current temperature is: " + str(current_temperature)
    upload(ARDUINO_WEATHER, current_temperature)
  else:
    print "No weather data found for location: "+CITY_NAME
  pass

upload(ARDUINO_START_SYNC);

upload_weather_info();
upload_time();

upload(ARDUINO_END_SYNC);
