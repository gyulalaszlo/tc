_ = require 'underscore'
handlers = require './_handlers'


# Accessing the current target via the '@' and '@<fieldname>' or '@<methodname>' shortcut
handlers.THIS_ACCESS = thisAccess = (scope, expr)->
  thisType = scope.target
  # If this is an access to plain "this" (for value types)
  unless expr.name
    { _type: 'this', type: thisType.id }

  # If this is a field access on a structured type
  else
    fieldName = expr.name.text
    accessedField = _.findWhere( thisType.fields ,name: fieldName)
    # check if the field exists
    unless accessedField
      throw new TokenError( expr.name, "Cannot find field '#{fieldName}' on type '#{thisType.name}'", fieldName  )
    accessedType = scope.type( accessedField.type )

    { _type: 'this', name: expr.name.text, start: expr.name.start, type: accessedType.id }

