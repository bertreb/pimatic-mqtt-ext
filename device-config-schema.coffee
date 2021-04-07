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
      onoffTopic:
        description: "Topic used for sending on/off message"
        type: "string"
        required: true
      colorTopic:
        description: "Topic used for sending RGB values"
        type: "string"
        required: true
      onoffStateTopic:
        description: "Topic for receiving on/off messages"
        type: "string"
        default: null
        required: false
      colorStateTopic:
        description: "Topic used for receiving RGB values"
        type: "string"
        default: null
        required: false
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
