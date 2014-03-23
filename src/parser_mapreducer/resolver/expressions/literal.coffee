_ = require 'underscore'
handlers = require './_handlers'

handlers.LITERAL = literal = (scope, expr)->
  makeLiteral = (type, value)-> { _type: 'literal', type: -1, literal: type, value: value, convertibleTo: [] }
  return switch expr.value._type
    when 'NUMERIC' then makeLiteral( 'numeric', expr.value.value  )
    when 'STRING' then makeLiteral( 'string', expr.value.value )
    else
      throw new Error("Literal of unknown type: #{JSON.stringify(expr)}")

