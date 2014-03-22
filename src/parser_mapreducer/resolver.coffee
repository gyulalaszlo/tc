_ = require 'underscore'
async = require 'async'
tokens = require '../tokens'


resolverCommon = require './resolver/common'
extendedTypes = require './resolver/extended_types'

# Normalize a list of packges.
exports.resolvePackageList = resolvePackageList = (packages, callback)->

  async.auto {
    # make sure we are using a workable order
    orderedTypes: (callback)->
      # A fixed order for the type declarations
      typeOrder = { ctype: 0, alias: 1, struct: 2, class: 3, mixin: 4, interface: 5  }
      ordered = _.map packages, (p)->
        # order the types by the order declared in typeOrder
        types = _.sortBy( p.types, (t)-> typeOrder[t.type._type] )
        # order the method sets by name
        methodSets = _.sortBy( p.method_sets, (ms)-> ( if ms.target then ms.target.text else '__unbound' ) )
        { name: p.name, types: _.values( types  ), methodSets: methodSets }
      callback( null, ordered )

    # TODO: add imported types before resolution
    extendedTypes: [ 'orderedTypes', (callback, results)->
      async.map results.orderedTypes, extendedTypes.addExtendedTypes, callback
    ]

    resolvePublished: [ 'extendedTypes', (callback, results)->
      async.map results.extendedTypes, proxifyPublishedTypes, callback
    ]

  }, (err, results)->
    #return callback( err, results.extendedTypes )
    callback( err, results.resolvePublished )

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
    typeName = resolverCommon.getExtendedTypename( type )
    # if we dont have it on catalog
    unless typeNameIndex[typeName]
      # check if this is an extension type
      throw new tokens.TokenError( resolverCommon.getTypeBase(type).base, "Cannot resolve type '#{typeName}'")

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

  # apply the resolver to each type
  typeMapperFns = resolverCommon.createTypeMapper pack, {

    # Add the ctypes (they are always safe to start with.
    ctype: (t)->
      makeType(t, raw: t.type.raw )

    # Aliases need their original resolved
    alias: (t)->
      original = resolveTypeName( t.type.original )
      makeType( t, original: original, dependsOn: [original] )

    'struct class mixin': (t)->
      fields = for field in t.type.fields
        fieldTypeId = resolveTypeName( field.type )
        { name: field.name.text, start: field.name.start, type: fieldTypeId }
      makeType( t, start: t.name.start, fields: fields, dependsOn: _.chain(fields).pluck('type').uniq().value().sort() )

    'interface': (t)->
      # TODO: do a proper type resolution
      makeType(t, start: t.name.start )

    'extended': (t)->
      base = typeNameIndex[t.base].id
      makeType( t, base: base, dependsOn: [base], extension: t.extension )
  }

  methodMapperFns = [
    (callback)->
      err = 0
      try
        result = _.map pack.methodSets, methodSetCheckerFn,
          typeNameIndex: typeNameIndex
          resolveTypeName: resolveTypeName
      catch e
        err = e
      return callback( err, result )
  ]

  async.parallel methodMapperFns.concat( typeMapperFns ), (err, results)->
    packageData = {
      name: pack.name
      types: _.flatten(results[1..-1])
      methodSets: results[0]
    }
    callback( err, packageData )


tryTypename = (typeNameIndex, t)->
    target = typeNameIndex[ t.text ]
    return target if target != undefined
    throw new tokens.TokenError( t, "Cannot find type with name: #{t.text}")


# Map function to get the extended types to be created from method declarations
methodSetCheckerFn = (ms)->

  # resolve the target first
  target = { type: null, id: -1 }
  if ms.target
    target = tryTypename( @typeNameIndex, ms.target )

  # then resolve the methods
  methods = _.map ms.methods, methodCheckerFn, @
  return {
    target: target.id
    methods: methods
  }

methodCheckerFn = (m)->
  func = m.func
  o = {
    name: m.name.text
    start: m.name.start
    args:_.map( func.args, methodArgCheckerFn, @)
    returns: _.map( func.returns, methodReturnCheckerFn, @ )
  }
  o


methodArgCheckerFn = (a)->
  argT = @resolveTypeName( a.type )
  {
    type: argT
    name: a.name.text
    start: a.name.start
  }

methodReturnCheckerFn = (r)->
  argT = @resolveTypeName( r )
  {
    type: argT
    start: resolverCommon.getTypeBase( r ).base.start
  }


