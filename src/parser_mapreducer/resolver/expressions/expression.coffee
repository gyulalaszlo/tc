_ = require 'underscore'
handlers = require './_handlers'

# Resolve an expression tree.
#
# This method simply dispatches to the appropriate handler
# or reports an error if no handlers are found.
module.exports = expression = ( scope, expr)->
  #console.log handlers
  handlerFn = handlers[ expr._type ]
  unless handlerFn
    console.log "WARN: Unknown expression type: #{expr._type}"
    return _.extend type: -1, expr
    throw new Error("Unknown expression type: '#{ expr._type }'")
  handlerFn( scope, expr )



