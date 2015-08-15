'use strict';
{EventEmitter} = require 'events'
serialport     = require 'serialport'
through        = require 'through'
_              = require 'lodash'

debug          = require('debug')('tentacle')
TentacleEdison = require './tentacle-edison'

MESSAGE_SCHEMA        = require 'tentacle-protocol-buffer/message-schema.json'
tentacleOptionsSchema = require 'tentacle-protocol-buffer/options-schema.json'

OPTIONS_SCHEMA =
  port:
    title: "Serial Port"
    type: "string"

class Plugin extends EventEmitter
  constructor: ->
    @options = {}
    @messageSchema = MESSAGE_SCHEMA
    @optionsSchema = _.clone tentacleOptionsSchema

    @tentacle = new TentacleEdison

    _.extend @optionsSchema.properties, OPTIONS_SCHEMA

  onMessage: (message) =>
    return unless @tentacle?
    @tentacle.onMessage message

  onConfig: (device) =>
    @setOptions device.options

  setOptions: (options={}) =>
    @options = options

    @tentacle.removeAllListeners()
    @tentacle.on "message", (message) => @emit 'message', _.extend devices: '*', message
    @tentacle.on "error", (error) => @emit 'error', error
    @tentacle.on "request-config", => @tentacle.onConfig @options
    @tentacle.start()

module.exports =
  messageSchema: MESSAGE_SCHEMA
  optionsSchema: OPTIONS_SCHEMA
  Plugin: Plugin
