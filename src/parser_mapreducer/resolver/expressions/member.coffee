_ = require 'underscore'
handlers = require './_handlers'
expression = require './expression'

handlers.MEMBER = member = (scope, expr)->
  base = expression( scope, expr.base )

  # fail if no base resolved
  if !base or base.type == -1
    fail( scope, expr, "Cannot resolve base for member expr.")
    # Otherwise the lookup failed

  # Figure out the type of base
  currentType = scope.type( base.type )

  # Create the output expression with an empty chain for now
  output = { _type: 'member', base: base, type: -1, chain: [] }

  # resolve the access chain and set it on the output
  output.chain = _.map expr.access_chain, (acc)->
    res = switch acc._type
      when 'ARRAY_ACCESS' then arrayAccess( scope, currentType, acc )
      when 'PROPERTY_ACCESS' then propertyAccess( scope, currentType, acc )

      else
        throw new Error("Unknown member access type: #{JSON.stringify(acc)}")


    currentType = scope.type( res.type )
    res

  output.type = currentType.id
  # return the built expression
  output


arrayAccess = (scope, currentType, acc)->
  # check if we are accessing an array
  unless currentType.extension and currentType.extension._type == 'array'
    fail( scope, acc, "Tried to access a non-array type like an array")

  # check the accessor scope
  accessWith = expression( scope, acc.name )

  # TODO: check to make sure the access is numeric(?)
  { _type: 'arrayAccess', type: scope.type(currentType.base).id, index: accessWith }


propertyAccess = (scope, currentType, acc)->
  targetType = currentType
  propertyName = acc.name.text
  accessThrough = "value"
  # check the types for valid property access
  if currentType.extension
    # We only care about pointers from the extended types
    # any other type is invalid
    if currentType.extension in ['pointer', 'reference']
      targetType = scope.type(currentType.base)
      accessThrough = "pointer"
    else
      fail( scope, acc, "Tried to access property '#{propertyName}' of an extended type #{ currentType.name}.", acc.name.start );


  # check if the underlying type is a real structured type
  unless targetType._type in ['struct', 'class', 'mixin']
    fail( scope, acc, "Tried to access property '#{propertyName}' of non-structured type '#{targetType.name}' through a pointer", acc.name.start )


  if field = _.findWhere( targetType.fields, name: propertyName )
    return { _type: 'property', name: propertyName, access: accessThrough, type: field.type }
  else
    fail( scope, acc, "Cannot find field '#{propertyName}' in type '#{targetType.name}'", acc.name.start )





fail = (scope, expr, msg, start)->
    throw new Error [
      "(#{ "#{start.line}:#{start.column}" if start} inside #{scope.path()})"
      msg
      "\n"
      "Tree: #{ JSON.stringify( expr ) }"
    ].join(' ')

