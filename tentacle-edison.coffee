{EventEmitter} = require 'events'
debug   = require('debug')('tentacle:client')
_ = require 'lodash'

try
  mraa = require 'mraa'
catch
  console.warn 'mraa not found, using mock-mraa'
  mraa = require './mock-mraa'

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
    pins = _.map @config.pins, (pin) =>
      try
        @_processPin pin
      catch error
        @emit 'error', error

    @_emitPins pins

  onConfig: (config) =>
    @_clearBroadcast()
    @_clearPins()

    @config = config

    _.each @config.pins, (pin) =>
      try
        @_setPinAction pin
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
    @_emitPins pins

  _clearPins: =>
    _.times 19, _setDigitalWrite

  _digitalRead: (pinNumber) =>
    gpio = new mraa.Gpio pinNumber
    gpio.read()

  _digitalWrite: (pinNumber, value) =>
    gpio = new mraa.Gpio pinNumber
    gpio.write value

  _emitPins: (pins) =>
    @emit 'message',
      version: 1
      topic: 'action'
      pins: pins
      response: true

  _setPwmWrite: (pinNumber, value) =>
    pwm = mraa.Pwm(pinNumber)
    pwm.write value / 255.0

  _processPin: (pin) =>
    @_setPinAction pin
    return @_readPin(pin) ? @_writePin(pin)

  _readPin: (pin) =>
    return unless _.contains ['digitalRead', 'analogRead'], pin.action

    value = @_digitalRead pin.number if pin.action == 'digitalRead'
    value = @_analogRead pin.number if pin.action == 'analogRead'

    {
      action: pin.action
      number: pin.number
      value:  value
    }

  _setPinAction: (pin) =>
    return @_setDigitalRead pin.number  if pin.action == 'digitalRead'
    return @_setDigitalWrite pin.number if pin.action == 'digitalWrite'
    return @_setAnalogRead pin.number   if pin.action == 'analogRead'
    return @_setPwmWrite pin.number     if pin.action == 'pwmWrite'

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

  _writePin: (pin) =>
    return unless _.contains ['digitalWrite', 'pwmWrite'], pin.action

    @_digitalWrite pin.number, pin.value if pin.action == 'digitalRead'
    @_pwmWrite pin.number, pin.value if pin.action == 'pwmWrite'

    {
      action: pin.action
      number: pin.number
      value:  pin.value
    }

module.exports = Tentacle
