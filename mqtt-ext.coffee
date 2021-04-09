module.exports = (env) ->

  # Pimatic MQTT ext
  Promise = env.require 'bluebird'
  assert = env.require 'cassert'
  Color = require 'color'
  colorSchema = require './color_schema'
  path = require('path')
  _ = require('lodash')
  M = env.matcher

  t =
    number: "number"
    string: "string"
    array: "array"
    date: "date"
    object: "object"
    boolean: "boolean"

  class MqttExtPlugin extends env.plugins.Plugin

    init: (app, @framework, @config) =>

      @deviceConfigDef = require('./device-config-schema.coffee')
      plugin = @

      @framework.deviceManager.registerDeviceClass 'MqttRGB',
        configDef: @deviceConfigDef.MqttRGB
        createCallback: (config, lastState) -> return new MqttRGB(plugin, config, lastState)

      @framework.ruleManager.addActionProvider(new MqttRGBActionProvider(@framework))
      @framework.ruleManager.addPredicateProvider(new MqttRGBPredicateProvider(@framework))

      # wait till all plugins are loaded
      @framework.on "after init", =>
        # Check if the mobile-frontend was loaded and get a instance
        mobileFrontend = @framework.pluginManager.getPlugin 'mobile-frontend'
        if mobileFrontend?
          mobileFrontend.registerAssetFile 'js', 'pimatic-mqtt-ext/app/mqtt-ext.coffee'
          mobileFrontend.registerAssetFile 'css', 'pimatic-mqtt-ext/app/mqtt-ext.css'
          mobileFrontend.registerAssetFile 'html', 'pimatic-mqtt-ext/app/mqtt-ext.html'
          mobileFrontend.registerAssetFile 'js', 'pimatic-mqtt-ext/app/spectrum.js'
          mobileFrontend.registerAssetFile 'css', 'pimatic-mqtt-ext/app/spectrum.css'
          mobileFrontend.registerAssetFile 'js', 'pimatic-mqtt-ext/app/async.js'
        else
          env.logger.warn 'your plugin could not find the mobile-frontend. No gui will be available'


  class BaseLedLight extends env.devices.Device

    WHITE_MODE: 'WHITE'
    COLOR_MODE: 'COLOR'

    getTemplateName: -> 'led-light'

    attributes:
      power:
        description: 'the current state of the light'
        type: t.boolean
        labels: ['on', 'off']
      color:
        description: 'color of the light'
        type: t.string
        unit: 'hex color'
      mode:
        description: 'mode of the light'
        type: t.boolean
        labels: ['color', 'white']
      brightness:
       description: 'brightness of the light'
       type: t.number
       unit: '%'

    template: 'led-light'

    actions:
      getPower:
        description: 'returns the current state of the light'
        returns:
          state:
            type: t.boolean
      getMode:
        description: 'returns the light mode'
      turnOn:
        description: 'turns the light on'
      turnOff:
        description: 'turns the light off'
      toggle:
        description: 'turns the light off or off'
      setWhite:
        description: 'set the light to white mode'
      setColor:
        description: 'set a light color'
        params:
          colorCode:
            type: t.string
      setBrightness:
        description: 'set the light brightness'
        params:
          brightnessValue:
            type: t.number
      changeDimlevelTo:
        description: "Sets the level of the dimmer"
        params:
          dimlevel:
            type: t.number

    constructor: (initState) ->
      unless @device
        throw new Error 'no device initialized'

      @name = @config.name
      @id = @config.id

      @power = initState?.power or 'off'
      @color = initState?.color or ''
      @brightness = initState?.brightness or 100
      @mode = initState?.mode or false

      super()

    _setAttribute: (attributeName, value) ->
      unless @[attributeName] is value
        @[attributeName] = value
        @emit attributeName, value

    _setPower: (powerState) ->
      #console.log "POWER" , powerState
      unless @power is powerState
        @power = powerState
        @emit "power", if powerState then 'on' else 'off'

    _updateState: (err, state) ->
      env.logger.error err if err

      if state
        if state.mode is @WHITE_MODE
          @_setAttribute 'mode', false
          hexColor = ''
        else if state.mode is @COLOR_MODE
          @_setAttribute 'mode', true
          if state.color is ''
            hexColor = '#FFFFFF'
          else
            hexColor = Color(state.color).hexString()
        #console.log "hexColor:", hexColor
        @_setPower(state.power) if state.power?
        @_setAttribute('brightness', state.brightness) if state.brightness?
        @_setAttribute('color', hexColor) if state.color?

    getPower: -> Promise.resolve @power
    getColor: -> Promise.resolve @color
    getMode: -> Promise.resolve @mode
    getBrightness: -> Promise.resolve @brightness

    getState: ->
      mode: if @mode then @COLOR_MODE else @WHITE_MODE
      color: if _.isString(@color) and not _.isEmpty(@color) then Color(@color).rgb() else ''
      power: @power
      brightness: @brightness

    turnOn: -> throw new Error "Function 'turnOn' is not implemented!"
    turnOff: -> throw new Error "Function 'turnOff' is not implemented!"
    setColor: -> throw new Error "Function 'setColor' is not implemented!"
    setWhite: -> throw new Error "Function 'setWhite' is not implemented!"
    setBrightness: (brightnessValue) -> throw new Error "Function 'setBrightness' is not implemented!"
    changeDimlevelTo: (dimLevel) -> @setBrightness(dimLevel)

    toggle: ->
      if @power is 'off' then @turnOn() else @turnOff()
      Promise.resolve()


  class MqttRGB extends BaseLedLight

    constructor: (@plugin, @config, lastState) ->
      mqttPlugin = @plugin.framework.pluginManager.getPlugin('mqtt')
      assert(mqttPlugin)
      #assert(mqttPlugin.brokers[@config.brokerId])

      shellyDeviceId = @config.deviceId
      @onoffStateTopic = @config.onoffStateTopic
      if @onoffStateTopic.indexOf("<deviceid>")>=0
        @onoffStateTopic = @onoffStateTopic.replace("<deviceid>", shellyDeviceId)
      @colorStateTopic = @config.colorStateTopic
      if @colorStateTopic.indexOf("<deviceid>")>=0
        @colorStateTopic = @colorStateTopic.replace("<deviceid>", shellyDeviceId)
      @onoffTopic = @config.onoffTopic
      if @onoffTopic.indexOf("<deviceid>")>=0
        @onoffTopic = @onoffTopic.replace("<deviceid>", shellyDeviceId)
      @colorTopic = @config.colorTopic
      if @colorTopic.indexOf("<deviceid>")>=0
        @colorTopic = @colorTopic.replace("<deviceid>", shellyDeviceId)

      @effectOn = @config.effectOn ? 2
      @effectOff = @config.effectOff ? 0
      @onMessage = @config.onMessage ? "on"
      @offMessage = @config.offMessage ? "off"

      @device = @
      @name = @config.name
      @id = @config.id
      @_dimlevel = lastState?.dimlevel?.value or 0

      @mqttPlugin = @plugin.framework.pluginManager.getPlugin('mqtt')
      unless @plugin.framework.pluginManager.isActivated('mqtt') and @mqttPlugin?
        env.logger.debug "MQTT not found or not activated"
        return

      @mqttClient = @mqttPlugin.brokers[@config.brokerId].client
      if @mqttClient?
        if @mqttClient.connected
          @onConnect()

        @mqttClient.on('connect', =>
          @onConnect()
        )
      else
        env.logger.debug "Mqtt broker client does not excist"

      initState = _.clone lastState
      for key, value of lastState
        initState[key] = value.value

      ###
      if @onoffStateTopic
        @mqttClient.on('message', @onoffMessageHandler = (topic, message) =>
          if @onoffStateTopic == topic
            switch message.toString()
              when @config.onMessage
                env.logger.debug "onMessage received"
                @turnOn()
              when @config.offMessage
                env.logger.debug "offMessage received"
                @turnOff()
              else
                env.logger.debug "#{@name} with id:#{@id}: Message is not harmony with onMessage or offMessage in config.json or with default values"
        )
      ###

      if @colorStateTopic
        @mqttClient.on('message', @colorMessageHandler = (topic, message) =>
          if @colorStateTopic == topic
            try
              if typeof message is 'object' and Object.keys(message).length != 0
                _message = message
              else
                _message = JSON.parse(message)
              if _message.mode? 
                if _message.mode is 'color' and _message.red? and _message.green? and _message.blue?
                  hexColor = "#{_message.red},#{_message.green},#{_message.blue}"
                  env.logger.debug "ColorState color message received: " + hexColor
                  @_updateState({color: hexColor, mode: COLOR_MODE})
                if _message.mode is 'white' and _message.white?
                  env.logger.debug "ColorState white message received: " + _message.white
                  @_updateState({color: '', mode: COLOR_MODE})
              if _message.ison?
                env.logger.debug "Ison message received: " + _message.ison
                @_updateState({power: Boolean _message.ison})
              if _message.gain?
                env.logger.debug "Gain message received: " + _message.gain
                @_updateState({brightness: Number _message.gain})
            catch e
              env.logger.debug "Invalid JSON message received, topic: " + topic + ", message: " + message        
        )

      super(initState)
      if @power is true then @turnOn() else @turnOff()

    onConnect: () ->
      if @onoffStateTopic
        @mqttClient.subscribe(@onoffStateTopic) #{ qos: @config.qos }
        env.logger.debug "Suscribed to: " + @onoffStateTopic

      if @colorStateTopic
        @mqttClient.subscribe(@colorStateTopic) #{ qos: @config.qos }
        env.logger.debug "Suscribed to: " + @colorStateTopic

    _updateState: (attr) ->
      state = _.assign @getState(), attr
      super null, state

    turnOn: ->
      @_updateState power: true
      _message =
        turn: @onMessage
        effect: @effectOn
      message = JSON.stringify(_message)
      @mqttClient.publish(@colorTopic, message, { qos: @config.qos })
      env.logger.debug "Message sent, topic: " + @colorTopic+ ", message: " + message
      Promise.resolve()

    turnOff: ->
      @_updateState power: false
      _message =
        turn: @offMessage
        effect: @effectOff
      message = JSON.stringify(_message)
      @mqttClient.publish(@colorTopic, message, { qos: @config.qos })
      env.logger.debug "Message sent, topic: " + @colorTopic+ ", message: " + message
      Promise.resolve()

    toggle: ->
      if @power is false then @turnOn() else @turnOff()
      Promise.resolve()

    setColor: (newColor) ->
      color = Color(newColor).rgb()
      @_updateState
        mode: @COLOR_MODE
        color: color

      currentState = @getState()
      _message =
        red: color.r
        green: color.g 
        blue: color.b
        gain: currentState.brightness
      message = JSON.stringify(_message)

      @mqttClient.publish(@colorTopic, message, { qos: @config.qos })
      env.logger.debug "Message sent, topic: " + @colorTopic+ ", message: " + message
      Promise.resolve()

    setWhite: ->
      @_updateState mode: @WHITE_MODE

      currentState = @getState()
      _message =
        white: 100
        gain: currentState.brightness
      message = JSON.stringify(_message)

      @mqttClient.publish(@colorTopic, message, { qos: @config.qos })
      env.logger.debug "White message sent: " + message
      Promise.resolve()

    setBrightness: (newBrightness) ->
      @_updateState brightness: newBrightness

      currentState = @getState()
      currentRGBColor = currentState.color
      _message =
        red: currentRGBColor.r
        green: currentRGBColor.g
        blue: currentRGBColor.b
        gain: currentState.brightness
      message = JSON.stringify(_message)

      @mqttClient.publish(@colorTopic, message, { qos: @config.qos })
      env.logger.debug "Brightness message sent: " + message
      Promise.resolve()

    destroy: () ->
      if @onoffStateTopic
        @mqttClient.unsubscribe(@onoffStateTopic)
        @mqttClient.removeListener('message', @onoffMessageHandler) if @onoffMessageHandler?

      if @colorStateTopic
        @mqttClient.unsubscribe(@colorStateTopic)
        @mqttClient.removeListener('message', @colorMessageHandler) if @colorMessageHandler?

      super()

  class MqttRGBPredicateProvider extends env.predicates.PredicateProvider

    presets: [
      {
        name: "switch turned on/off"
        input: "{device} is turned on"
      }
    ]

    constructor: (@framework) ->

    # ### parsePredicate()
    parsePredicate: (input, context) ->  

      supportedMqttRgbClasses = ["MqttRGB"]
      switchDevices = _(@framework.deviceManager.devices).values().filter(
        (device) => device.config.class in supportedMqttRgbClasses
      ).value()

      device = null
      state = null
      match = null

      stateAcFilter = (v) => v.trim() isnt 'is switched' 
      M(input, context)
        .matchDevice(switchDevices, (next, d) =>
          next.match([' is', ' is turned', ' is switched'], acFilter: stateAcFilter, type: 'static')
            .match([' on', ' off'], param: 'state', type: 'select', (next, s) =>
              # Already had a match with another device?
              if device? and device.id isnt d.id
                context?.addError(""""#{input.trim()}" is ambiguous.""")
                return
              assert d?
              assert s in [' on', ' off']
              device = d
              state = s.trim() is 'on'
              match = next.getFullMatch()
          )
        )
 
      # If we have a match
      if match?
        assert device?
        assert state?
        assert typeof match is "string"
        # and state as boolean.
        return {
          token: match
          nextInput: input.substring(match.length)
          predicateHandler: new MqttRGBPredicateHandler(device, state)
        }
      else
        return null

  class MqttRGBPredicateHandler extends env.predicates.PredicateHandler

    constructor: (@device, @state) ->
      @dependOnDevice(@device)
    setup: ->
      @stateListener = (s) => @emit 'change', (s is @state)
      @device.on 'power', @stateListener
      super()
    getValue: -> @device.getUpdatedAttributeValue('power').then( (s) => (s is @state) )
    destroy: -> 
      @device.removeListener "power", @stateListener
      super()
    getType: -> 'state'

  class MqttRGBActionProvider extends env.actions.ActionProvider
      constructor: (@framework) ->

      parseAction: (input, context) =>
        supportedMqttRgbClasses = ["MqttRGB"]
        mqttRGBDevices = _(@framework.deviceManager.devices).values().filter(
          (device) => device.config.class in supportedMqttRgbClasses
        ).value()

        hadPrefix = false

        # Try to match the input string with: set ->
        m = M(input, context).match(['shelly '])

        device = null
        color = null
        match = null
        variable = null

        # device name -> color
        m.matchDevice mqttRGBDevices, (m, d) ->
          # Already had a match with another device?
          if device? and device.id isnt d.id
            context?.addError(""""#{input.trim()}" is ambiguous.""")
            return

          device = d

          m.match [' to '], (m) ->
            m.or [
              # rgb hex like #00FF00
              (m) ->
                # TODO: forward pattern to UI
                #m.match [/(#[a-fA-F\d]{6})(.*)/], (m, s) ->
                m.match "#", (m) ->
                  m.match [/(#[a-fA-F\d]{6})(.*)/], (m, s) ->
                    color = s.trim()
                    match = m.getFullMatch()

              # color name like red
              (m) -> m.match _.keys(colorSchema), (m, s) ->
                  color = colorSchema[s]
                  match = m.getFullMatch()

              # color by temperature from variable like $weather.temperature = 30
              (m) ->
                m.match ['temperature based color by variable '], (m) ->
                  m.matchVariable (m, s) ->
                    variable = s
                    match = m.getFullMatch()
            ]

        if match?
          assert device?
          # either variable or color should be set
          assert variable? ^ color?
          assert typeof match is "string"
          return {
            token: match
            nextInput: input.substring(match.length)
            actionHandler: new MqttRGBActionHandler(@, device, color, variable)
          }
        else
          return null

  class MqttRGBActionHandler extends env.actions.ActionHandler
    constructor: (@provider, @device, @color, @variable) ->
      @_variableManager = null

      if @variable
        @_variableManager = @provider.framework.variableManager

    executeAction: (simulate) =>
      getColor = (callback) =>
        if @variable
          @_variableManager.evaluateStringExpression([@variable])
            .then (temperature) =>
              temperatureColor = new Color()
              hue = 30 + 240 * (30 - temperature) / 60;
              temperatureColor.hsl(hue, 70, 50)

              hexColor = '#'
              hexColor += temperatureColor.rgb().r.toString(16)
              hexColor += temperatureColor.rgb().g.toString(16)
              hexColor += temperatureColor.rgb().b.toString(16)

              callback hexColor, simulate
        else
          callback @color, simulate

      getColor @setColor

    setColor: (color, simulate) =>
      if simulate
        return Promise.resolve(__("would log set color #{color}"))
      else
        @device.setColor color
        return Promise.resolve(__("set color #{color}"))


  myMqttExtPlugin = new MqttExtPlugin()
  return myMqttExtPlugin
