{EventEmitter} = require 'events'
through = require 'through'
mraa = require 'mraa'
debug   = require('debug')('tentacle:client')
_ = require 'lodash'

class Tentacle extends EventEmitter
  constructor: (tentacleConn) ->

  start: =>
    debug 'start called'

  messageTentacle: (msg) =>
    debug "Sending message to the tentacle: #{JSON.stringify(msg, null, 2)}"
    try
      @tentacleConn.write @tentacleTransformer.toProtocolBuffer(msg)

    catch error
      debug "error sending message to Tentacle: #{JSON.stringify(msg, null, 2)}"
      @emit 'error', error

  onMessage: (message) =>
    return unless message?.payload?

    @messageTentacle _.extend({}, message.payload, topic: 'action')


  onConfig: (config) =>
    @_clearBroadcast()
    @_clearPins()

    @config = config

    @config.pins, (pin) =>
      try
        @_setPinMode pin.number, pin.action
      catch error
        @emit 'error', error

    if @config.broadcastPins
      clearInterval @_broadcastIntervalId
      @_broadcastIntervalId = setInterval @_broadcastPins, @config.broadcastInterval

  _analogRead: (pinNumber) =>
    aio = new mraa.Aio pinNumber
    aio.read()

  _broadcastPins: =>
    pins = _.compact _.map(@config.pins, @_readPin)
    @emit 'message',
      version: 1
      topic: 'action'
      pins: pins
      response: true

  _clearPins: =>
    _.times 19, _setDigitalWrite

  _digitalRead: (pinNumber) =>
    gpio = new mraa.Gpio pinNumber
    gpio.read()

  _readPin: (pin) =>
    return unless _.contains ['digitalRead', 'analogRead'], pin.action

    value = @_digitalRead pin.pinNumber if pin.action == 'digitalRead'
    value = @_analogRead pin.pinNumber if pin.action == 'analogRead'

    {
      action: pin.action
      number: pin.pinNumber
      value:  value
    }

  _setPinMode: (pinNumber, mode) =>
    return @_setDigitalRead pinNumber  if mode == 'digitalRead'
    return @_setDigitalWrite pinNumber if mode == 'digitalWrite'
    return @_setAnalogRead pinNumber   if mode == 'analogRead'
    return @_setPwmWrite pinNumber     if mode == 'pwmWrite'

  _setAnalogRead: (pinNumber) =>
    aio = new mraa.Aio pinNumber

  _setDigitalRead: (pinNumber) =>
    gpio = new mraa.Gpio pinNumber
    gpio.dir mraa.DIR_IN

  _setDigitalWrite: (pinNumber) =>
    gpio = new mraa.Gpio pinNumber
    gpio.dir mraa.DIR_OUT
    gpio.write 0

  _setPwmWrite: (pinNumber) =>
    pwm = new mraa.Pwm pinNumber

module.exports = Tentacle
