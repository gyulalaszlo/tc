_ = require 'underscore'
async = require 'async'
tokens = require '../tokens'

# Normalize a list of packges.
exports.resolvePackageList = resolvePackageList = (packages, callback)->

  async.auto {
    # make sure we are using a workable order
    orderedTypes: (callback)->
      typeOrder = { ctype: 0, alias: 1, struct: 2, class: 3, mixin: 4, interface: 5  }
      ordered = _.map packages, (p)->
        types = _.sortBy( p.types, (t)-> typeOrder[t.type._type] )
        { name: p.name, types: _.values( types  ) }
      callback( null, ordered )

    # TODO: add imported types before resolution
    extendedTypes: [ 'orderedTypes', (callback, results)->
      async.map results.orderedTypes, addExtendedTypes, callback
    ]

    resolvePublished: [ 'extendedTypes', (callback, results)->
      async.map results.extendedTypes, proxifyPublishedTypes, callback
    ]

  }, (err, results)->
    callback( err, results.resolvePublished )



# Add any extended types derived from the published normal ones
# created in the first step.
# Returns the list of types to be created (names only)
addExtendedTypes = (pack, callback)->
  extendedTypes = []

  # Helper to convert an extended type to a list of types
  # that mimic that extension while renrencing their base
  # type.
  makeExtendedType = (t)->

    # We dont need the base type
    makeExtendedTypeToList( t )[1..-1]

  async.parallel [

    # An alias needs its original to be created if its an extended type
    (callback)->
      mapToTypes pack, ['alias'], callback, (t)->
        makeExtendedType( t.type.original )

    # Structured data needs its fields checked for extended types
    (callback)->
      mapToTypes pack, ['struct', 'class', 'mixin'], callback, (t)->
        for field in t.type.fields
          makeExtendedType( field.type )

  ], (err, results)->
    # filter the duplicates
    typesToAdd = _.uniq( _.flatten(results), (t)-> t.name.text )
    # append to the pack
    pack.types = pack.types.concat typesToAdd
    callback( err, pack )



# First, all the types declared by each package must be normalized, so
# cross-package lookup can start. First we set up proxy types for every
# public type, so we can create the head of our typelist, and can start
# assigning ids to types
# TODO: what if a type is an alias for a type declared in another package?
proxifyPublishedTypes = (pack, callback)->
  types = []

  typeNameIndex = {}
  typeMapper = (t, idx)->
    { name: t.name.text, type: t.type._type, id: idx, data: t }
  for v in _.map( pack.types, typeMapper  )
    typeNameIndex[ v.name ] = v


  resolveTypeName = (type)->
    typeName = getExtendedTypename( type )
    # if we dont have it on catalog
    unless typeNameIndex[typeName]
      # check if this is an extension type
      throw new tokens.TokenError( getTypeBase(type).base, "Cannot resolve type '#{typeName}'")

    typeNameIndex[typeName].id


  # Helper shortcut function to make a type
  makeType = (typedef, attrs...)->
    thisType = typeNameIndex[ typedef.name.text ]
    typeAttributes =
      id: thisType.id
      _type: typedef.type._type
      name: typedef.name.text
      docs: typedef.docs
      start: typedef.name.start
      dependsOn: []

    _.extend( typeAttributes, attrs... )

  async.parallel [

    # Add the ctypes (they are always safe to start with.
    (callback)->
      mapToTypes pack, ['ctype'], callback, (t)->
        makeType(t, raw: t.type.raw )

    # Aliases need their original resolved
    (callback)->
      mapToTypes pack, ['alias'], callback, (t)->
        original = resolveTypeName( t.type.original )
        makeType( t, original: original, dependsOn: [original] )

    (callback)->
      mapToTypes pack, ['struct', 'class', 'mixin'], callback, (t)->
        fields = for field in t.type.fields
          fieldTypeId = resolveTypeName( field.type )
          { name: field.name.text, start: field.name.start, type: fieldTypeId }
        makeType( t, start: t.name.start, fields: fields, dependsOn: _.chain(fields).pluck('type').uniq().value() )

    (callback)->
      # TODO: do a proper type resolution
      mapToTypes pack, ['interface'], callback, (t)->
        makeType(t, start: t.name.start )

    (callback)->
      mapToTypes pack, ['extended'], callback, (t)->
        base = typeNameIndex[t.base].id
        makeType( t, base: base, dependsOn: [base] )



  ], (err, results)->
    packageData = {
      name: pack.name
      types: _.flatten(results)
    }
    callback( err, packageData )


# Create a list of well-ordered extensions
# by reversing the extension tree of types
#
#     { base: { base: { text: "foo" }, extension: null }, extension: {_type:"pointer"} }
#
# gets converted to
#
#     [ { base: {/*...*/}, name: "foo" }, { extension:{ _type: "pointer"}, name: "foo*"  } ]
#
makeExtendedTypeToList = (t)->
  o = []; it = t
  while it.extension
    # add the extension to the end of the type
    o.unshift { name: { text: getExtendedTypename(it)}, base: getExtendedTypename(it.base) , extension: it.extension, type:{_type: 'extended'} }
    it = it.base
  o.unshift { base: it.base, name: it.base.text }
  o


# helper to find types fast
mapToTypes = (pack, _typenames, callback, iter)->
  try
    res = _.chain(pack.types).filter((e)-> e.type._type in _typenames).map(iter).value()
    callback( null, res)
  catch e
    callback( e, [])



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

