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
    publishedTypesNoAliases: [ 'orderedTypes', (callback, results)->
      async.map results.orderedTypes, proxifyPublishedTypes, callback
        #callback( err, globalTypes )
    ]


  }, (err, results)->
    #console.log results.publishedTypesNoAliases
    callback( err, results.publishedTypesNoAliases )


# First, all the types declared by each package must be normalized, so
# cross-package lookup can start. First we set up proxy types for every
# public type, so we can create the head of our typelist, and can start
# assigning ids to types
# TODO: what if a type is an alias for a type declared in another package?
proxifyPublishedTypes = (pack, callback)->
  types = []

  typeNameIndex = {}
  for v in _.map( pack.types, (t, idx)-> { name: t.name.text, type: t.type._type, id: idx, data: t } )
    typeNameIndex[ v.name ] = v

  getTypeBase = (type)->
    return type.base unless type.extension
    return getTypeBase( type.base )


  # Get a string representing the given type
  getExtendedTypename = (type)->
    ext = type.extension
    return type.base.text unless ext
    # otherwise recurse
    getExtendedTypename( type.base) + switch ext._type
      when "array" then "[#{ext.size}]"
      when "pointer" then "*"
      when "reference" then "&"


  resolveTypeName = (type)->
    typeName = getExtendedTypename( type )
    # if we dont have it on catalog
    unless typeNameIndex[typeName]
      # check if this is an extension type
      typeBase = getTypeBase(type)
      resolved_base = 
      console.log type, typeName
      throw new tokens.TokenError( getTypeBase(type), "Cannot resolve type '#{typeName}'")

    typeNameIndex[typeName].id


  #return callback( null, pack )
  # helper to find types fast
  mapToTypes = (_typenames, callback, iter)->
    try
      res = _.chain(pack.types).filter((e)-> e.type._type in _typenames).map(iter).value()
      callback( null, res)
    catch e
      callback( e, [])

  # Helper shortcut function to make a type
  makeType = (typedef, attrs...)->
    thisType = typeNameIndex[ typedef.name.text ]
    typeAttributes =
      id: thisType.id
      _type: typedef.type._type
      name: typedef.name.text
      docs: typedef.docs
      start: typedef.name.start
      #dependsOn: []

    _.extend( typeAttributes, attrs... )

  # make a proxy type
  makeProxy = (typedef, attrs...)-> makeType( typedef, {_proxy: true },  attrs...  )


  async.auto {

    # Add the ctypes (they are always safe to start with.
    ctypes: (callback)->
      mapToTypes ['ctype'], callback, (t)->
        makeType(t, raw: t.type.raw )

    # Aliases need their original resolved
    aliases: (callback)->
      mapToTypes ['alias'], callback, (t)->
        original = resolveTypeName( t.type.original )
        makeType( t, original: original )

    structured: (callback)->
      res = mapToTypes ['struct', 'class', 'mixin'], callback, (t)->
        fields = for field in t.type.fields
          fieldTypeId = resolveTypeName( field.type )
          { name: field.name.text, start: field.name.start, type: fieldTypeId }
        makeType(t, start: t.name.start, fields: fields )

    # TODO: add imported types & interfaces

  }, (err, results)->
    packageData = {
      name: pack.name
      types: _.flatten([ results.ctypes, results.aliases, results.structured ])
    }
    callback( err, packageData )





