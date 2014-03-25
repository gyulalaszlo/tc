_ = require 'underscore'
async = require 'async'
tokens = require '../../tokens'


resolverCommon = require './common'


# First, all the types declared by each package must be normalized, so
# cross-package lookup can start. First we set up proxy types for every
# public type, so we can create the head of our typelist, and can start
# assigning ids to types
# TODO: what if a type is an alias for a type declared in another package?
exports.resolvePublishedTypes = resolvePublishedTypes = (pack, callback)->
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
    typeAttributes =
      id: typedef.id
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
        { name: field.name.text, start: field.name.start, type: fieldTypeId, docs: field.docs }
      makeType( t, start: t.name.start, fields: fields, dependsOn: _.chain(fields).pluck('type').uniq().value().sort() )

    'interface': (t)->
      # TODO: do a proper type resolution
      #methods = for meth t.type.methods
      methodCheckerPartial = _.partial( methodCheckerFn, -1, false )
      # then resolve the methods
      methods = _.chain( t.type.methods ).map( methodCheckerPartial, {
          typeNameIndex: typeNameIndex
          resolveTypeName: resolveTypeName
      }).each( (el)->
        delete el.id
        delete el.target
        delete el.body
        delete el.methodSet
      ).value()
      makeType(t, start: t.name.start, methods: methods )

    'extended': (t)->
      base = typeNameIndex[t.base].id
      makeType( t, base: base, dependsOn: [base], extension: t.extension )
  }

  methodMapperFns = [
    (callback)->
      err = null
      try
        checkedMethodSets = _.map pack.methodSets, methodSetCheckerFn,
          typeNameIndex: typeNameIndex
          resolveTypeName: resolveTypeName
        checked = _( checkedMethodSets )
        #result = _.chain(checkedMethodSets).map()
        result =
          methodSets: checked.pluck( 'methodSet')
          methods: _.flatten( checked.pluck('methods') )
      catch e
        err = e
      callback( err, result )
  ]

  async.parallel methodMapperFns.concat( typeMapperFns ), (err, results)->
    return callback(err, null) if err
    # Decompose the results
    methodSets = results[0]
    types = _.flatten( results[1..-1] )
    #console.log _.chain(types).filter((t)->t._type in ['struct', 'class'] ).pluck('fields').flatten().pluck('docs').value().join("\n")
    # create the output
    packageData = {
      name: pack.name
      types: types
      methodSets: methodSets.methodSets
      methods: methodSets.methods
    }
    callback( err, packageData )

# Try to find a type for a typename
tryTypename = (typeNameIndex, t)->
    target = typeNameIndex[ t.text ]
    return target if target != undefined
    throw new tokens.TokenError( t, "Cannot find type with name: #{t.text}")


# Map function to get the extended types to be created from method declarations
#
# TODO: Maybe move the id generation somewhere else.
# Using underscore's map gives us the index, but async's map does not.
methodSetCheckerFn = (ms, idx)->

  # resolve the target first
  target = { type: null, id: -1 }
  if ms.target
    target = tryTypename( @typeNameIndex, ms.target )

  # set the id for the checker
  methodCheckerPartial = _.partial( methodCheckerFn, target.id, true )
  # then resolve the methods
  methods = _.map ms.methods, methodCheckerPartial, @
  o = methodSet:{ id: ms.id, target: target.id }, methods: methods
  o


# Check and resolve a method
methodCheckerFn = (targetTypeId, resolveBody, m)->
  func = m.func
  args = _.map( func.args, methodArgCheckerFn, @)
  returns = _.map( func.returns, methodReturnCheckerFn, @ )
  # create the dependency list
  dependsOn = []
  dependsOn.push( targetTypeId ) if targetTypeId != -1
  # add the dependencies from the arguments and return types
  dependsOn = dependsOn.concat( _.pluck( args, 'type' ), _.pluck( returns, 'type') )
  o = {
    id: m.id
    target: targetTypeId
    methodSet: m.methodSet
    name: m.name.text
    start: m.name.start
    args: args
    returns: returns
    dependsOn: _.chain( dependsOn ).sortBy( (e)->e).uniq( true ).value()
    body: null
    docs: m.docs
  }
  o.body = func.body.statements if resolveBody
  console.log o unless resolveBody
  o


# Check and resolve a method argument type
methodArgCheckerFn = (a)->
  argT = @resolveTypeName( a.type )
  {
    type: argT
    name: a.name.text
    start: a.name.start
  }

# Check and resolve a method return type
methodReturnCheckerFn = (r)->
  argT = @resolveTypeName( r )
  {
    type: argT
    start: resolverCommon.getTypeBase( r ).base.start
  }

