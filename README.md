# ESPHome Weather Station

Read this in other language: [French](README.fr.md)

![Main photo of the weather station](images/station.jpg)

## Introduction

The electronic part of this weather station is based on the model described in an article in Elektor magazine published in May 2020 entitled [Remake Elektor weather station](https://www.elektormagazine.com/labs/remake-elektor-weather-station) (an evolution of ESP32 Weather Station described in an article in the same magazine in January 2019).

The article details the creation of a weather station based on a set of sensors referenced WH-SP-WS02 ([Datasheet](docs/Weather_Sensor_Assembly_Updated.pdf)) whose original electronics are removed to be replaced by a sensor daughter board relaying the information to a motherboard built around an ESP32 (ESP32 Pico Kit).

An OpenSource firmware [GitHub - ElektorLabs/191148-RemakeWeatherStation: RemakeWeatherStation](https://github.com/ElektorLabs/191148-RemakeWeatherStation) is available to run the whole system. Unfortunately, I did not find my happiness with it, it is not yet complete enough and suffers from some shortcomings that make it very difficult to use it as is.

I therefore decided to use ESPHome as a replacement for the original program in order to simplify the development of functionality but above all to greatly extend its capabilities.

The board detailed in Elektor's article is finally limited to a voltage converter and a 5V/3V voltage adaptation for the ESP32.

It is therefore quite simple to recreate this weather station independently of Elektor's PCB. For the connections, please use the data included in the YAML file.

With the kind [permission of Elektor](https://www.elektormagazine.com/labs/remake-elektor-weather-station#comment-70057), the schematic diagrams are available here:  [Schematics](schematics/).

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

Note: On the main picture of the weather station, there is a box on top, it is an [independent rain detection module](https://github.com/hugokernel/esphome-rain-detector).

## Installation

In order to install the firmware on the ESP32, I invite you to follow the procedure described on the ESPHome website: [Getting Started with ESPHome](https://esphome.io/guides/getting_started_command_line.html)

## Electronics

The Elektor electronic board is to be used as is or, in view of its simplicity, to be reproduced on a test board.

The Elektor publication is wrong, in fact, they use GPIO 34 (wind speed) and 38 (precipitation measurement) directly without a pullup resistor,
Moreover, these inputs / outputs do not integrate a pull-up resistor, **so it is necessary to add a pullup resistor (~10kOhms) on GPIO34 and GPIO38**.

## Mechanical

For the mast, I used a metal reinforced PVC tube that you can find in any DIY store in the plumbing department. In order to fix it on a wall, I modeled it on OpenSCAD [one piece](wall_pipe_support.scad) that I then printed in PETG.

Here is the printed piece next to the box containing the solar panel charger controller:

![Photo of the power supply box](images/boitier_alimentation.jpg)

## Powering

One of the flaws that I reproach to the original Elektor board is to have linked the technology of the power source to the motherboard (in this case the lead battery), indeed, a [MAX8212](docs/MAX8211-MAX8212.pdf) used with some peripheral components allows to cut the power supply when it goes below a threshold defined by the value of 3 resistors. This threshold has been chosen to protect a lead battery.

Since a weather station is supposed to stay on all the time, I don't really understand the above choice because:

* We use a solar panel to charge the battery but in this case we are obliged to use a charge regulator which also protects the battery and therefore the integrated protection circuit is redundant and can even cause problems.
* The station is connected to an unlimited power source (domestic power via a regulator) and in this case the protection circuit is useless.

In the 2 cases mentioned above, a strong link is inserted on the motherboard with the battery technology, which should be done, imho, on an independent card / module.

For my part, I chose to power my weather station via a [30W solar panel](https://www.amazon.fr/gp/product/B07MZKLS4Z/ref=as_li_tl?ie=UTF8&camp=1642&creative=6746&creativeASIN=B07MZKLS4Z&linkCode=as2&tag=digita049-21&linkId=f280ba939aba379ee4586d3211f88c44) and a [relatively basic charge controller](https://www.amazon.fr/gp/product/B07K57WZVP/ref=as_li_tl?ie=UTF8&camp=1642&creative=6746&creativeASIN=B07K57WZVP&linkCode=as2&tag=digita049-21&linkId=d3af4f9616f8d0f0eea5031ee318a9b9).

If you are using Elektor's motherboard with an independent load controller module, do not forget to lower the cut-off threshold of the MAX8212.

At the output of the solar panel, the [INA219](docs/ina219.pdf) circuit allows the power generated by the solar panel to be measured. I plan to replace it with [INA3221](docs/ina3221.pdf) in order to also measure the total consumption of the weather station and help me to refine the global consumption (a RFLink with [OpenMQTTGateway](https://github.com/1technophile/OpenMQTTGateway) and a second ESP32 kit is connected to the station).

I use a 7A lead battery recovered from an old inverter.

To size the whole thing, I recommend the [BatteryStuff Tools](https://www.batterystuff.com/kb/tools/solar-calculator.html) tool which is very handy.

Currently, I can't say that I have succeeded in making my weather station totally energy independent because of a bad exposure of my solar panel and a too high consumption of an additional module (rain detection module).

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
      # Don't forget to add a pulling resistor, see README
      number: GPIO34
      mode: INPUT
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

#### Direction

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
      # Don't forget to add a pulling resistor, see README
      number: GPIO38
      mode: INPUT
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

* [weatherstation.yaml](weatherstation.yaml): The ESPHome configuration file
* [network.yaml](network.yaml): Your network information
* [secrets.yaml](secrets.yaml): The secret information about your network.
* [wall_pipe_support.scad](wall_pipe_support.scad): The OpenSCAD file for mat support.
