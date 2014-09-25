#include <SPI.h>
#include <glcdfont.c>
#include <Adafruit_GFX.h>
#include <Adafruit_ILI9340.h>

#define PIN_cs 10
#define PIN_dc 9
#define PIN_rst 8

#define ARDUINO_START_SYNC 0
#define ARDUINO_WEATHER 2
#define ARDUINO_TIME 3
#define ARDUINO_TRANSMISSION 4
#define ARDUINO_DISK_USAGE 5
#define ARDUINO_BITCOIN 6
#define ARDUINO_END_SYNC 1

struct Torrents {
  unsigned long  eta;
  unsigned short count;
  unsigned short download_speed;
  unsigned short upload_speed;
  byte progress;
};

struct Temperature {
  float internal;
  float external;
};

struct Disk {
  unsigned long used;
  unsigned long available;
};

unsigned long current_time;

Temperature      temperature;
Torrents         torrents;
Disk             disk;

Adafruit_ILI9340 screen = Adafruit_ILI9340(PIN_cs, PIN_dc, PIN_rst);

void render_not_synced() {
  screen.fillScreen(ILI9340_WHITE);
}

void render_clock() {
  screen.fillScreen(ILI9340_BLACK);
}

void read_disk_usage() {
  Serial.println(F("Reading disk usage"));
  disk.used               = Serial.read();
  Serial.println(disk.used);
  disk.available          = Serial.read();
  Serial.println(disk.available);
}

void reset_vars() {
  Serial.println(F("Resseting vars:"));
  current_time         = 0;
  temperature.internal = 0.0f;
  temperature.external = 0.0f;

  torrents.progress       = 0;
  torrents.count          = 0;
  torrents.upload_speed   = 0;
  torrents.download_speed = 0;
  torrents.eta            = 0;

  disk.used               = 0;
  disk.available          = 0;
}

byte read_command() {
  return Serial.read();
}

void read_torrents() {
  Serial.println(F("Reading torrents..."));
  torrents.eta            = Serial.read();
  torrents.count          = Serial.read();
  torrents.progress       = Serial.read();
  torrents.download_speed = Serial.read();
  torrents.upload_speed   = Serial.read();

  Serial.println(F("ETA:"));
  Serial.println(torrents.eta);
  Serial.println(F("Count:"));
  Serial.println(torrents.count);
  Serial.println(F("Progress:"));
  Serial.println(torrents.progress);
  Serial.println(F("Download:"));
  Serial.println(torrents.download_speed);
  Serial.println(F("Upload:"));
  Serial.println(torrents.upload_speed);
}

void read_time() {
  Serial.println(F("Reading time:"));
  current_time = Serial.read();
  Serial.println(current_time);
}

void read_temperature() {
  temperature.external = Serial.read();
  Serial.println(F("Read temperature:"));
  Serial.println(temperature.external);
}

void read_serial_sync() {
  if (Serial.available() > 0 && read_command() == ARDUINO_START_SYNC) {
    Serial.println(F("Sync start;"));
    reset_vars();
    byte command = 0;
    while(command != ARDUINO_END_SYNC) {
      command = read_command();

      switch(command) {
        case ARDUINO_WEATHER:
          read_temperature();
        break;

        case ARDUINO_TRANSMISSION:
          read_torrents();
        break;

        case ARDUINO_DISK_USAGE:
          read_disk_usage();
        break;

        case ARDUINO_TIME:
          read_time();
        break;
      }
    }

    Serial.println(F("Sync finsihed;"));
    render_clock();
  }
}

void setup() {
  Serial.begin(9600);
  Serial.println(F("Initializing clock"));
  screen.setRotation(0);

  reset_vars();
  render_not_synced();
}

void loop() {
  read_serial_sync();
  delay(5000);
}
