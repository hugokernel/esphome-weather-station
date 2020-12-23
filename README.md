# ESPHome Weather Station

Read this in other language: [French](README.fr.md)

![Main photo of the weather station](images/station.jpg)

## Introduction

The electronic part of this weather station is based on the model described in an article in Elektor magazine published in May 2020 entitled [Remake Elektor weather station](https://www.elektormagazine.com/labs/remake-elektor-weather-station) (an evolution of ESP32 Weather Station described in an article in the same magazine in January 2019).

The article details the creation of a weather station based on a set of sensors referenced WH-SP-WS02 ([Datasheet](docs/Weather_Sensor_Assembly_Updated.pdf)) whose original electronics are removed to be replaced by a sensor daughter board relaying the information to a motherboard built around an ESP32 (ESP32 Pico Kit).

An OpenSource firmware ([GitHub - ElektorLabs/191148-RemakeWeatherStation: RemakeWeatherStation](https://github.com/ElektorLabs/191148-RemakeWeatherStation)) is available to run the whole system. Unfortunately, I did not find my happiness with it, it is not yet complete enough and suffers from some shortcomings that make it very difficult to use it as is.

I therefore decided to use ESPHome as a replacement for the original program in order to simplify the development of functionality but above all to greatly extend its capabilities.

The board detailed in Elektor's article is finally limited to a voltage converter and a 5V/3V voltage adaptation for the ESP32.

It is therefore quite simple to recreate this weather station independently of Elektor's PCB. For the connections, please use the data included in the YAML file.

![Case photo](images/boitier.jpg)

### Inspirations

* [Remake Elektor weather station | Elektor Magazine](https://www.elektormagazine.com/labs/remake-elektor-weather-station)
* [GitHub - mkuoppa/esphomeweatherstation: ESPHome based weatherstation station](https://github.com/mkuoppa/esphomeweatherstation)
* [ESP8266 Weather Station - with Wind and Rain Sensors | Tysonpower.de](https://tysonpower.de/blog/esp8266-weather-station)

## Features

* Measurement of temperature / relative humidity / atmospheric pressure
* Wind speed / Direction
* Precipitation daily / per minute
* Ambient brightness
* Input voltage
* Solar panel:
  * Voltage
  * Current
  * Power
  * Daily accumulated power
* RGB status led with WS2812
* All ESPHome features
  * MQTT
  * OTA (Over The Air updates)
  * [The list is long](https://esphome.io/)

Note: On the main picture of the weather station, there is a box on top, it is an independent rain detection module, I will publish the configuration of this project separately.

## Installation

In order to install the firmware on the ESP32, I invite you to follow the procedure described on the ESPHome website: [Getting Started with ESPHome](https://esphome.io/guides/getting_started_command_line.html)

## Mechanical

For the mast, I used a metal reinforced PVC tube that you can find in any DIY store in the plumbing department. In order to fix it on a wall, I modeled it on OpenSCAD [one piece](wall_pipe_support.scad) that I then printed in PETG.

Here is the printed piece next to the box containing the solar panel charger controller:

![Photo of the power supply box](images/boitier_alimentation.jpg)

## Explanations

### Measurement of temperature / humidity / atmospheric pressure

These 3 quantities are measured by a Bosch BME280 sensor and its configuration in ESPHome is as follows:

```yaml
  - platform: bme280
    address: 0x76
    update_interval: 60s
    iir_filter: 16x
    temperature:
      name: "${friendly_name} temperature"
      oversampling: 16x
    humidity:
      name: "${friendly_name} humidity"
      oversampling: 16x
    pressure:
      name: "${friendly_name} pressure"
      oversampling: 16x
```

The sensor is to be put inside the box containing the original sensor electronics.

Initially, I also included an AM2320 sensor to compare the sensor values with the following configuration:

```yaml
  - platform: am2320
    setup_priority: -100
    temperature:
      id: am2320_temperature
      name: "${friendly_name} AM2320 temperature"
    humidity:
      id: am2320_humidity
      name: "${friendly_name} AM2320 humidity"
    update_interval: 60s
```

The temperatures and humidities of the sensors were averaged before being sent to Home Assistant (see below), it was of course possible to access the data of each sensor.

```yaml
  - platform: template
    name: "${friendly_name} temperature"
    icon: "mdi:thermometer"
    unit_of_measurement: "°C"
    lambda: |-
      return (
        id(bme280_temperature).state
        +
        id(am2320_temperature).state
      ) / 2;

  - platform: template
    name: "${friendly_name} humidity"
    icon: "mdi:water-percent"
    unit_of_measurement: "%"
    lambda: |-
      return (
        id(bme280_humidity).state
        +
        id(am2320_humidity).state
      ) / 2;
```

At the end of my tests, the BME280 sensor is more reliable and more accurate than the AM2320 sensor.

### Wind measurements

#### Speed

The wind speed sensor is connected to general input 34.
The ESPHome pulse_counter platform is used to perform the measurement.

```yaml
  - platform: pulse_counter
    pin:
      number: GPIO34
      mode: INPUT_PULLUP
    unit_of_measurement: 'm/s'
    name: "${friendly_name} wind speed"
    icon: 'mdi:weather-windy'
    count_mode:
      rising_edge: DISABLE
      falling_edge: INCREMENT
    internal_filter: 13us
    update_interval: 60s
    # rotations_per_sec = pulses / 2 / 60
    # circ_m = 0.09 * 2 * 3.14 = 0.5652
    # mps = 1.18 * circ_m * rotations_per_sec
    # mps = 1.18 * 0.5652 / 2 / 60 = 0,0055578
    filters:
      - multiply: 0.0055578
```

#### Management

The wind direction is made in the sensor by means of magnets (switch reed) that switch resistors. Depending on the final value, the direction is deduced.

An example of the ESPHome configuration:

```yaml
  - platform: resistance
    sensor: source_sensor
    id: resistance_sensor
    configuration: DOWNSTREAM
    resistor: 10kOhm
    internal: true
    name: Resistance Sensor
    reference_voltage: 3.9V
    accuracy_decimals: 1
    filters:
      - median:
          window_size: 7
          send_every: 4
          send_first_at: 3
    on_value:
      - if:
          condition:
            sensor.in_range:
              id: resistance_sensor
              above: 15000
              below: 15500
          then:
            - text_sensor.template.publish:
                id: wind_dir_card
                state: "N"
            - sensor.template.publish:
                id: wind_heading
                state: 0.0
[...]
```

#### Rain

The measurement of precipitation is carried out by a system of pendulum composed of 2 cups, the water runs in the funnel of the sensor and fills the high cup, once the latter is filled, it tips by gravity. This movement is detected by a magnetic sensor (reed switch) and an impulse is generated.
The sensor documentation indicates that each pulse corresponds to 0.2794mm of precipitation.

```yaml
  - platform: pulse_counter
    pin:
      number: GPIO38
      mode: INPUT_PULLUP
    unit_of_measurement: 'mm'
    name: "${friendly_name} rain gauge"
    icon: 'mdi:weather-rainy'
    id: rain_gauge
    internal: true
    count_mode:
      rising_edge: DISABLE
      falling_edge: INCREMENT
    internal_filter: 13us
    update_interval: 60s
    filters:
      # Each 0.011" (0.2794mm) of rain causes one momentary contact closure
      - multiply: 0.2794
    accuracy_decimals: 4
```

In order to have more relevant information, these measurements are converted into precipitation per minute and the daily total is calculated.

```yaml
  - platform: integration
    name: "${friendly_name} rainfall per min"
    id: rain_per_min
    time_unit: min
    unit_of_measurement: 'mm'
    icon: 'mdi:weather-rainy'
    sensor: rain_gauge

  - platform: total_daily_energy
    name: "${friendly_name} total daily rain"
    power_id: rain_gauge
    unit_of_measurement: 'mm'
    icon: 'mdi:weather-rainy'
    # x60 To convert to aggregated rain amount
    filters:
      - multiply: 60
```

#### Brightness

Remember to position the brightness sensor as high as possible on your weather station so that it is not shaded by the mast or any part of the weather station.

```yaml
  - platform: tsl2561
    id: lux_meter
    name: "${friendly_name} ambient Light"
    address: 0x39
    update_interval: 5s
    integration_time: 14ms
    gain: 1x
```

## Files

* weatherstation.yaml: The ESPHome configuration file
* network.yaml: Your network information
* secrets.yaml: The secret information about your network.
* wall_pipe_support.scad: The OpenSCAD file for mat support.

