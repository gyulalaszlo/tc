_ = require 'underscore'
async = require 'async'
resolverCommon = require './common'


# Add any extended types derived from the published normal ones
# created in the first step.
#
# INPUT: the package data with the types ordered (in any predetermined order)
#
# OUTPUT: The package data in the same format with the extended types added.
#
# Returns the list of types to be created (names only)
addExtendedTypes = (pack, callback)->
  extendedTypes = []

  typeMapperFns = resolverCommon.createTypeMapper pack, {

    # An alias needs its original to be created if its an extended type
    alias: (t)->
      makeExtendedType( t.type.original )

    # Structured data needs its fields checked for extended types
    'struct class mixin': (t)->
      #makeExtendedType( field.type )
      #_.map( t.type.fields, makeExtendedType )
      for field in t.type.fields
        makeExtendedType( field.type )

    'interface': (t)->
      _.map( t.type.methods, methodCheckerFn )

  }

  # The functions to creates the extended types necessary from the methods,
  # and copies all the methods
  methodMapperFns = [
    (callback)->
      return callback( null, _.map( pack.methodSets, methodSetCheckerFn ) )
  ]
  async.parallel methodMapperFns.concat( typeMapperFns ), (err, results)->
    # filter the duplicates
    typesToAdd = _.uniq( _.flatten(results), (t)-> t.name.text )
    # append to the pack
    pack.types = pack.types.concat typesToAdd
    return callback( err, pack )


# Map function to get the extended types to be created from method declarations
methodSetCheckerFn = (ms)->
  _.map ms.methods, methodCheckerFn

methodCheckerFn = (m)->
  func = m.func
  # check the arguments
  o = [
    _.map( func.args, methodArgCheckerFn)
    _.map( func.returns, methodReturnCheckerFn )
  ]
  o


methodArgCheckerFn = (a)-> makeExtendedType(a.type)
methodReturnCheckerFn = (r)-> makeExtendedType(r)

# Helper to convert an extended type to a list of types
# that mimic that extension while renrencing their base
# type.
makeExtendedType = (t)->
  # We dont need the base type
  makeExtendedTypeToList( t )[1..-1]


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
    o.unshift {
      name: { text: resolverCommon.getExtendedTypename(it) }
      base: resolverCommon.getExtendedTypename(it.base)
      extension: it.extension
      type:{_type: 'extended'}
    }
    it = it.base
  o.unshift { base: it.base, name: it.base.text }
  o

module.exports =
  addExtendedTypes: addExtendedTypes
