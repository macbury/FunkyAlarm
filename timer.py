ARDUINO_USB      = '/dev/tty.usbserial'
CITY_NAME        = "Cracow,PL"
BITCOIN_CURRENCY = "PLN";

import transmissionrpc;
import serial, json, requests, os.path, time, commands, os, re;
from datetime import datetime, timedelta;
#arduino = serial.Serial(ARDUINO_USB, 9600)

ARDUINO_START_SYNC                  = 0;
ARDUINO_WEATHER                     = 2;
ARDUINO_TIME                        = 3;
ARDUINO_TRANSMISSION                = 4;
ARDUINO_DISK_USAGE                  = 5;
ARDUINO_BITCOIN                     = 6;
ARDUINO_END_SYNC                    = 1;

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

def upload_transmission():
  client           = transmissionrpc.Client(address='localhost')
  running_torrents = 0
  total_eta        = 0
  total_progress   = 0.0
  download_speed   = 0
  upload_speed     = 0
  for torrent in client.get_torrents():
    try:
      seconds = torrent.eta.total_seconds()
    except Exception as e:
      print e
      seconds = -1
    if seconds > 0:
      print "Getting info for: "+ torrent.name
      running_torrents += 1
      total_progress   += torrent.progress
      total_eta        += seconds;
      download_speed   += torrent.rateDownload;
      upload_speed     += torrent.rateUpload;
    else:
      print "Skipping:" + torrent.name

  if running_torrents > 0:
    total_progress = total_progress/running_torrents
  else:
    total_progress = 0

  upload(ARDUINO_TRANSMISSION, [total_eta, running_torrents, total_progress, download_speed, upload_speed])
  pass

def upload_weather_info():
  current_weather = get_weather()
  if current_weather:
    current_temperature = current_weather['main']['temp']
    print "Current temperature is: " + str(current_temperature)
    upload(ARDUINO_WEATHER, current_temperature)
  else:
    print "No weather data found for location: "+CITY_NAME
  pass

def upload_bitcoin():
  resp = requests.get(url="https://blockchain.info/ticker")
  data = json.loads(resp.text)
  btc  = data[BITCOIN_CURRENCY]
  if not btc is None:
    upload(ARDUINO_BITCOIN, [btc["15m"], BITCOIN_CURRENCY])

def upload_disk_usage():
  used      = 0
  available = 0
  for line in os.popen("df").read().split("\n"):
    result = re.findall('(\d+)', line)
    if len(result) >= 3:
      used      += int(result[1])
      available += int(result[2])
  upload(ARDUINO_DISK_USAGE, [used, available])
  pass
upload(ARDUINO_START_SYNC);

upload_bitcoin();
upload_weather_info();
upload_time();
upload_transmission();
upload_disk_usage();

upload(ARDUINO_END_SYNC);
