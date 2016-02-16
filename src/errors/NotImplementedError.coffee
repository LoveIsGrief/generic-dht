class NotImplementedError extends Error
  constructor: (o, funcName)->
    super
    @message = "#{funcName} not implemented in #{o.constructor.name}"

module.exports = NotImplementedError
