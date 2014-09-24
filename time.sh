#!/bin/bash

USB_DEVICE=/dev/ttyUSB0
CITY=Cracow,PL

TEMP_WEATHER_FILE=/tmp/weather.json

ARDUINO_COMMAND_START='S'
ARDUINO_COMMAND_END='E'

ARDUINO_COMMAND_DISK_USAGE='u'
ARDUINO_COMMAND_TIME='d'
ARDUINO_COMMAND_TORRENT='b'
ARDUINO_COMMAND_TEMPERATURE='t'

function configure_usb {
  stty -F /dev/ttyUSB0 cs8 9600 ignbrk -brkint -icrnl -imaxbel -opost -onlcr -isig -icanon -iexten -echo -echoe -echok -echoctl -echoke noflsh -ixon -crtsct;
}

function download_weather {
  if test "`find $TEMP_WEATHER_FILE -mmin +30`" || [ ! -f $TEMP_WEATHER_FILE ]
  then
    echo "Downloading new forecast for: $CITY";
    curl "http://api.openweathermap.org/data/2.5/weather?q=$CITY&units=metric" > /tmp/weather.json;
  else
    echo "Using cached weather";
  fi

  TEMPERATURE_KEY=$( grep -Po '"temp":([0-9]*)' $TEMP_WEATHER_FILE )
  TEMPERATURE=$( echo $TEMPERATURE_KEY | grep -Po '[0-9]*' )
  echo "Current temperature is: $TEMPERATURE degrees";
  arduino_command $ARDUINO_COMMAND_TEMPERATURE, $TEMPERATURE;
}

function disk_usage {
  DISK_USAGE=(`df --total | grep "total" | grep -Po "[0-9]* "`)
  echo "Disk space left: ${DISK_USAGE[2]}"
  arduino_command $ARDUINO_COMMAND_DISK_USAGE ${DISK_USAGE[2]};
}

function regexp {
  echo $( $1 | grep -Po "$2" | grep -Po "$3" )
}

function list_torrents {
  TORRENTLIST=`transmission-remote --list | sed -e '1d;$d;s/^ *//' | cut -s -d " " -f1`
  for TORRENTID in $TORRENTLIST
  do
    PERCENT_DONE=$( regexp "transmission-remote -t $TORRENTID -i" "Percent Done: [0-9]*.[0-9]*" "[0-9]{1,2}.[0-9]{0,2}" )
    ETA_SECONDS=$( transmission-remote -t $TORRENTID -i | grep  "ETA: **" | grep -Po "[0-9]* seconds"  | grep -Po "[0-9]*" )

    if [ -z "${ETA_SECONDS}" ]; then
      ETA_SECONDS = "0";
    fi

    if [ -z "${PERCENT_DONE}" ]; then
      PERCENT_DONE = "0";
    fi

    echo "Pushing torrent: $PERCENT_DONE % and ETA seconds: $ETA_SECONDS"
    push_arduino $ARDUINO_COMMAND_TORRENT;
    push_arduino $PERCENT_DONE;
    push_arduino $ETA_SECONDS;
  done;
}

function arduino_command {
  echo "Pushing arduino command $1 with content $2";
  push_arduino $1;
  push_arduino $2;
}

function push_arduino {
  echo $1 > $USB_DEVICE;
}

configure_usb;
push_arduino $ARDUINO_COMMAND_START;

download_weather;
list_torrents;
disk_usage;

arduino_command $ARDUINO_COMMAND_TIME, $(date +%s);

push_arduino $ARDUINO_COMMAND_END;
