module.exports = {
  title: "pimatic-mqtt-ext device config schemas"
  MqttRGB: {
    title: "MqttExt Color Temperature Light Device"
    type: "object"
    properties:
      brokerId:
        description: "The brokerId of the MQTT broker which can be set for each device. Use 'default' for default Broker"
        type: "string"
        default: "default"
      deviceId:
        description: "The Shelly DeviceId"
        type: "string"
        required: true
      onoffTopic:
        description: "Topic used for sending on/off message"
        type: "string"
        default: "shellies/shellyrgbw2-<deviceid>/color/0/command"
      colorTopic:
        description: "Topic used for sending RGB values"
        type: "string"
        default: "shellies/shellyrgbw2-<deviceid>/color/0/set"
      onoffStateTopic:
        description: "Topic for receiving on/off messages"
        type: "string"
        default: "shellies/shellyrgbw2-<deviceid>/color/0"
      colorStateTopic:
        description: "Topic used for receiving RGB values"
        type: "string"
        default: "shellies/shellyrgbw2-<deviceid>/color/0/status"
      onMessage:
        description: "Payload for sending 'on' command"
        type: "string"
        default: "ON"
      offMessage:
        description: "Payload for sending 'off' command"
        type: "string"
        default: "OFF"
      qos:
        description: "MQTT publish QOS for color and on/off payloads on state and set topics"
        type: "number"
        default: 0
      retain:
        description: "MQTT retain option for color and on/off payloads on the state topics"
        type: "boolean"
        default: false
  }
}
