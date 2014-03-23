_ = require 'underscore'
handlers = require './_handlers'

handlers.VARIABLE = variable = (scope, expr)->
  varName = expr.name.text
  # check the scope for this variable
  if scope.has varName
    return { _type: 'var', name: varName, start: expr.name.start, type: scope.get(varName) }


  throw new Error [
    "(#{JSON.stringify(expr.name.start)} inside #{scope.path()})"
    "Cannot find "
    "variable #{varName}"
    #"Between '#{ddscope.type(a.type)}' and '#{scope.type(b.type)}'"
    "\n"
    "Scope: #{ JSON.stringify( scope.variables(), null, 4 ) }"
    "\n"
    "Tree: #{ JSON.stringify( expr ) }"

  ].join(' ')


