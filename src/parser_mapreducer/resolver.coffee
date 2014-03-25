_ = require 'underscore'
async = require 'async'


extendedTypes = require './resolver/extended_types'
resolvePublicTypes = require './resolver/resolve_public_types'

addIdsToPackages = require './resolver/add_ids_to_packages'

# Normalize a list of packges.
exports.resolvePackageList = resolvePackageList = (packages, callback)->

  # Create a composite function from the separate tasks
  fn = async.compose(
    resolveMethodBodies
    resolvePublished
    addIdsToPackages # NOTE: This method modifies the package data instead of copying it.
    createExtendedTypes
    orderedTypes
  )
  # call it
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

ScopeStack = require './resolver/scope_stack'
expressions = require './resolver/expressions'

expression = expressions.resolve

# Resolve the bodies of the methods inside the packages.
#
# This function creates a shallow copy of pack and remaps
# the methodSets inside it
packageMethodSetResolver = (pack, callback)->
  # Create the scope stack root
  scopeStack = new ScopeStack( null, pack.types, pack.methods)
  scopeStack.push pack.name
  methodResolverFn = _.partial( methodResolver, scopeStack)
  interfaceResolverFn = _.partial( interfaceResolver, scopeStack)
  #
  # Function to resolve the method sets
  resolveMethodSets = (callback)->
    async.map pack.methods, methodResolverFn, (err, results)->
      #return callback( err, packOut ) if err
      #packOut.methods = results
      callback( err, results )

  # Function to resolve the interfaces
  resolveInterfaces = (callback)->
    # Get a shortened copy of the interface tyepes
    #
    interfaces = _.where(pack.types, _type: 'interface')
    async.map interfaces, interfaceResolverFn, callback

  async.parallel [resolveMethodSets, resolveInterfaces], (err, results)->
    # create a shallow copy of pack for our manipulation
    packOut = _.clone( pack )
    packOut.methods = []
    # on error return this temporary object
    return callback(err, packOut) if err
    # otherwise merge the results
    [methodSets, interfaces] = results
    packOut.methods = methodSets
    # replace the interfaces with the resolved types
    for t,i in packOut.types
      continue unless t._type == 'interface'
      replacementInterface = _.findWhere( interfaces, id: t.id )
      unless replacementInterface
        throw new Error("Cannot find resolved interface for id:#{t.id}")
      packOut.types[i] = replacementInterface
    # return the replaced interfaces
    callback( null, packOut)


interfaceResolver = (scope, iface, callback )->
  console.log "Resolving interface:", iface
  callback( null, iface)
#methodSetBodyResolver = (scope, methodSet, callback)->
  #methodSetOut = _.clone(methodSet)
  ## Prepare the scope for our parent
  #scopeStack = new ScopeStack( scope, {})
  #methodResolverFn = _.partial( methodResolver, scopeStack)
  #async.map methodSet.methods, methodResolverFn, (err, results)->
    ## Handle any errors
    #return callback(err, null) if err
    ## If ok, we replace the methods in the methodset output.
    #methodSetOut.methods = results
    #callback( null, methodSetOut )


# Copy the in
methodResolver = (scope, method, callback)->
  # Create the output
  methodOut = _.clone method
  methodOut.body = []
  err = null
  targetType = scope.type(method.target)

  # create the new scope for the statements
  scopeStack = new ScopeStack( scope, {}, {}, scope.type(method.target) )
  scopeStack.push targetType.name if targetType
  scopeStack.push method.name

  # add all the arguments to the scope
  for arg in method.args
    scopeStack.set arg.name, arg.type

  # add a new level to the scope stack, so we can find out the variables
  # declared inside the stack
  scopeStack.push "body"
  # try to resolve the body
  try
    methodOut.body = _.map method.body, _.partial( statementResolver, scopeStack )
  catch e
    err = e
  callback( err, methodOut )


# Resolve a single statement
statementResolver = (scope, statement)->
  switch statement._type
    when 'EXPR' then { _type: 'expr', expr: expression( scope, statement.expr ) }
    when 'RETURN' then { _type: 'return', expr: expression( scope, statement.expr ) }

    when 'CASSIGN'
      # resolve the initializer
      initializerExpr = expression( scope, statement.expr )
      unless initializerExpr
        statementJson = JSON.stringify(statement)
        throw new Error("Cannot resolve right hand side of CAssign: - #{statementJson}")

      # check the return type
      varType = initializerExpr.type #...
      unless varType
        initializerExprJson = JSON.stringify(initializerExpr)
        throw new Error("Cannot resolve type for left side of CAssign: - #{initializerExprJson}")

      # get the name
      varName = statement.name
      scope.set varName.text, varType
      { _type: 'cassign', name: varName.text, type: varType, start: statement.name.start, expr: initializerExpr }

    else
      console.log "WARN: Unknown statement type: #{statement._type}"
      statement



## Resolve an expression tree.
##
## This method simply dispatches to the appropriate handler
## or reports an error if no handlers are found.
#expression = ( scope, expr)->
  #handlerFn = expressionHandlers[ expr._type ]
  #unless handlerFn
    #console.log "WARN: Unknown expression type: #{expr._type}"
    #return _.extend type: -1, expr
    #throw new Error("Unknown expression type: '#{ expr._type }'")
  #handlerFn( scope, expr )


## The handlers fore each expression
#expressionHandlers = {}


## Accessing the current target via the '@' and '@<fieldname>' or '@<methodname>' shortcut
#thisAccess = (scope, expr)->
  #thisType = scope.target
  ## If this is an access to plain "this" (for value types)
  #unless expr.name
    #{ _type: 'this', type: thisType.id }

  ## If this is a field access on a structured type
  #else
    #fieldName = expr.name.text
    #accessedField = _.findWhere( thisType.fields ,name: fieldName)
    ## check if the field exists
    #unless accessedField
      #throw new TokenError( expr.name, "Cannot find field '#{fieldName}' on type '#{thisType.name}'", fieldName  )
    #accessedType = scope.type( accessedField.type )

    #{ _type: 'this', name: expr.name.text, start: expr.name.start, type: accessedType.id }

#_.extend expressionHandlers,
  #THIS_ACCESS: thisAccess

