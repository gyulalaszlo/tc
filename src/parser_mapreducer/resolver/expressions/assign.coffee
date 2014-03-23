_ = require 'underscore'
handlers = require './_handlers'
expression = require './expression'


handlers.ASSIGN = assign = (scope, expr)->
  a = expression( scope, expr.a )
  b = expression( scope, expr.b )

  # Helper to output an assign object
  makeAssign = ( a,b, type)-> { _type: 'assign', a:a, b: b, type: type }
  # Check if the types are ok
  #
  # If the types are an exact match, the op should succeed
  return makeAssign(a,b,a.type) if a.type == b.type

  # If the right hand side is a literal, check if the literal can be converted
  # to the correct type
  if b._type == 'literal'
    # TODO: do a proper check of convertible types
    return makeAssign(a,b,a.type)

  # Otherwise the lookup failed
  throw new Error [
    "(inside #{scope.path()})"
    "Type mismatch: "
    "Assignment op: #{expr.op}"
    "Between '#{scope.type(a.type)}' and '#{scope.type(b.type)}'"
    "\n A: '#{JSON.stringify a}'\n B:'#{JSON.stringify b}'"
    "\n"
    "Tree: #{ JSON.stringify( expr ) }"

  ].join(' ')

