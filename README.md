# pimatic-mqtt-ext
Pimatic-mqtt extensions

This plugin is an extension of pimatic-mqtt.
The plugin provides a MQTT RGB device for the Shelly RGBW2.
Its largely based on the mqtt device from [iMarvinS pimatic-led-light](https://github.com/iMarvinS/pimatic-led-light) and is adapted for the ShellyRGBW2.


The MqttRGB device requires the pimatic-mqtt plugin to be installed so that it can connect to a broker.
The brokerId is coming from pimatic-mqtt configuration.
```
{
      "brokerId": "default"
      "onoffTopic": "myOnOffTopic"
      "colorTopic": "myColorSetTopic"
      "onoffStateTopic": "myOnOffStateTopic"
      "colorStateTopic": "myColorStateTopic"
      "onMessage": "ON"
      "offMessage": "OFF"
}
```

### Actions
The action syntax
```
shelly <MqttRGB device> to [<hex color code> | <color name>]
```