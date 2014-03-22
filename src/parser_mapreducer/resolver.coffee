_ = require 'underscore'
async = require 'async'


extendedTypes = require './resolver/extended_types'
resolvePublicTypes = require './resolver/resolve_public_types'

# Normalize a list of packges.
exports.resolvePackageList = resolvePackageList = (packages, callback)->


  # Create a composite function from the separate tasks
  fn = async.compose(
    #resolveMethodBodies
    resolvePublished
    createExtendedTypes
    orderedTypes
  )
  #fn = async.compose(  resolvePublished, createExtendedTypes, orderedTypes  )
  fn packages, (err, results)->
    callback( err, results )


# Task list
# =========

# make sure we are using a workable order
orderedTypes = ( packages, callback)->
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
createExtendedTypes = (packagesWithTypesOrdered, callback)->
  async.map packagesWithTypesOrdered, extendedTypes.addExtendedTypes, callback


# After we have created any necessary top-level extended types, we can
# start resolving the top-level type declarations and method targets,
# arguments and return types.
#
resolvePublished = (packagesWithExtendedTypes, callback)->
  async.map packagesWithExtendedTypes, resolvePublicTypes.resolvePublishedTypes, callback


# Resolve the statement lists inside method bodies.
resolveMethodBodies = (packagesWithPublishedTypesResolved, callback)->
  async.map packagesWithPublishedTypesResolved, packageMethodSetResolver, callback


# Method set resolvers
# ====================

class ScopeLevel
  constructor: (@name)->
    @values = {}
  set: (key, val)-> @values[key] = val
  get: (key)-> @values[key]
  has: (key)-> @values[key] != undefined

class ScopeStack
  constructor: (@parent, types, methods)->
    @levels = []
    @typeIdMap = _.clone typeIdMap

  push: (name)-> @levels.push new ScopeLevel(name)
  pop: ()->
    throw new Error("Tried to pop empty scope") unless @levels.length > 0
    @levels.pop()

  current: -> @levels[ @levels.length - 1 ]

  # Set something to be visible from the levels bellow this one
  set: (key, val)-> @current().set( key, val )
  # Does this scope stack have the given key
  has: (key)->
    for l in @levels.reverse
      return true if l.has( key )
    # call the parent if necessary
    return @parent.has(key) if @parent
    false
  # Get a key from the scope stack
  get: (key)->
    for l in @levels.reverse
      return l.get( key) if l.has( key )
    # call the parent if necessary
    return @parent.get(key) if @parent
    undefined




# Resolve the bodies of the methods inside the packages.
#
# This function creates a shallow copy of pack and remaps
# the methodSets inside it
packageMethodSetResolver = (pack, callback)->
  # create a shallow copy of pack for our manipulation
  packOut = _.clone( pack )
  packOut.methodSets = []
  # Create the scope stack root
  scopeStack = new ScopeStack( null, pack.types)
  methodResolverFn = _.partial( methodResolver, scopeStack)
  #
  async.map pack.methodSets, methodSetBodyResolver, (err, results)->
    return callback( err, packOut ) if err
    packOut.methodSets = results
    callback( null, packOut )


methodSetBodyResolver = (scope, methodSet, callback)->
  methodSetOut = _.clone(methodSet)
  # Prepare the scope for our parent
  scopeStack = new ScopeStack( scope, {})
  methodResolverFn = _.partial( methodResolver, scopeStack)
  async.map methodSet.methods, methodResolverFn, (err, results)->
    # Handle any errors
    return callback(err, null) if err
    # If ok, we replace the methods in the methodset output.
    methodSetOut.methods = results
    callback( null, methodSetOut )


# Copy the in
methodResolver = (scope, method, callback)->
  methodOut = _.clone method
  scopeStack = new ScopeStack( scope, {} )
  methodOut.body = _.map method.body, statementResolver, scopeStack
  callback( null, methodOut )


# Resolve a single statement
statementResolver = (statement)->
  statement
