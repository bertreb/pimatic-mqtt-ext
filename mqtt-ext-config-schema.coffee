# pimatic-mqtt-ext configuration options
module.exports = {
  title: "Plugin config options"
  type: "object"
  properties: {
    debug:
      description: "Debug mode. Writes debug messages to the pimatic log, if set to true."
      type: "boolean"
      default: false
    brokerId:
      description: "The brokerId of the MQTT broker which can be set for each device. Use 'default' for default Broker"
      type: "string"
      default: "default"
  }
}