NotImplementedError = require '../errors/NotImplementedError'


class BaseQueryHandler
  ###
  Required values to be able to call the handler
  Order is important and should match the order of args for `main`
  ###
  @VALUES = []

  ###
  The expected value of the q param in the query message
  ###
  @NAME = "__REPLACE_THIS__"

  constructor: () ->
# No easy way to access class vars in subclasses
    @values = @constructor.VALUES
    @name = @constructor.NAME

  checkMessage: (message)->

    if not message
      throw new TypeError "No message"

    if not message.a
      throw new TypeError "Arguments ('a') not found in message"

    if typeof message.a != "object"
      throw new TypeError "Arguments ('a') is not an object"

    if not message.q
      throw new TypeError "Query name ('q') not found in message"

    if message.q != @name
      throw new TypeError "Cannot handle queries of type #{message.q}"

  getArgs: (argsDict)->
    argNames = Object.keys argsDict
    for value in @values
      if value not in argNames
        throw new TypeError "'#{value}' expected to be in arguments ('a') dictionary keys"
      argsDict[value]

  ###
  @param message {Object} a valid message
  @returns {Object} Reponse dict
  ###
  handle: (message)->
    @checkMessage message
    args = @getArgs message.a
    @main.apply @, args

  ###
  Override this in subclasses and give it the same number of arguments as you defined in `VALUES`
  @returns {Object} Response dict
  ###
  main: ->
    throw new NotImplementedError(@, "main")

module.exports = BaseQueryHandler
