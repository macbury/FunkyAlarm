#!/bin/bash

USB_DEVICE=/dev/ttyUSB0;
CITY=Cracow,PL;
STORAGE_MEDIA=/var/media/SAMSUNG;

TEMP_WEATHER_FILE=/tmp/weather.json;

ARDUINO_COMMAND_START='S';
ARDUINO_COMMAND_END='E';

ARDUINO_COMMAND_TIME='d'l
ARDUINO_COMMAND_TORRENT='b';
ARDUINO_COMMAND_TEMPERATURE='t';

push_arduino() {
  echo $1;
}

download_weather() {
  if test "`find $TEMP_WEATHER_FILE -mmin +30`" || [ ! -f $TEMP_WEATHER_FILE ]
  then
    echo "Downloading new forecast for: $CITY";
    curl "http://api.openweathermap.org/data/2.5/weather?q=$CITY&units=metric" > /tmp/weather.json;
  else
    echo "Using cached weather";
  fi

  TEMPERATURE=$( grep -o '"temp":[0-9]\{1,3\}' $TEMP_WEATHER_FILE | grep -o "[0-9]*" )
  echo "Current temperature is: $TEMPERATURE degrees";
  push_arduino $ARDUINO_COMMAND_TEMPERATURE;
  push_arduino $TEMPERATURE;
}

list_torrents() {
  TORRENTLIST=`transmission-remote --list | sed -e '1d;$d;s/^ *//' | cut -s -d " " -f1`
  for TORRENTID in $TORRENTLIST
  do
    PERCENT_DONE=$( regexp "transmission-remote -t $TORRENTID -i | grep -o Percent Done: [0-9]*.[0-9]* | grep -o [0-9]{1,2}.[0-9]{0,2}" )
    ETA_SECONDS=$( transmission-remote -t $TORRENTID -i | grep  "ETA: **" | grep -o "[0-9]* seconds"  | grep -o "[0-9]*" )

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


push_arduino $ARDUINO_COMMAND_START;

download_weather;
list_torrents;

push_arduino $ARDUINO_COMMAND_TIME;
push_arduino $(date +%s);

push_arduino $ARDUINO_COMMAND_END;
