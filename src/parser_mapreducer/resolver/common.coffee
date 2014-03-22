_ = require 'underscore'
async = require 'async'


# Create a task list for async.parallel.
#
# For each  typelist: mapFunc pair in handlers:
# map mapFunc to all types in pack matching typelist
# then collect and merge the results.
mapHandlersToTypes = (pack, handlers=[], callback)->
  # create a list
  mapFns = createTypeMapper( pack, handlers )
  # map it in a parallel way
  async.parallel mapFns, (err, results)->
    return callback(err, null) if err
    callback( null, _.flatten(results) )


createTypeMapper = (pack, handlers)->
  # create a list
  _.map handlers, (handler, name)->
    matchedTypes = name.split /\s+/
    return (callback)->
      mapToTypes( pack, matchedTypes, callback, handler )

# helper to find types fast
mapToTypes = (pack, _typenames, callback, iter)->
  try
    res = _.chain(pack.types).filter((e)-> e.type._type in _typenames).map(iter).value()
    return callback( null, res)
  catch e
    return callback( e, [])

# Return the base declaration (the token of the base in the deepest nesting)
getTypeBase = (type)->
  return type unless type.extension
  return getTypeBase( type.base )


# Get a string representing the given type
getExtendedTypename = (type)->
  ext = type.extension
  return type.base.text unless ext
  # otherwise recurse
  getExtendedTypename( type.base) + getExtensionString( ext )


# Helper to get the text for an extension.
getExtensionString = (ext)->
  switch ext._type
    when "array" then "[#{ext.size}]"
    when "pointer" then "*"
    when "reference" then "&"


module.exports =
  createTypeMapper: createTypeMapper
  mapHandlersToTypes: mapHandlersToTypes
  mapToTypes: mapToTypes

  getTypeBase: getTypeBase
  getExtendedTypename: getExtendedTypename
  getExtensionString: getExtensionString
