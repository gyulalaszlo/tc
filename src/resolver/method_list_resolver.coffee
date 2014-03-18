_ = require 'underscore'

ExpressionTreeResolver = require './expression_tree_resolver'
CAssignStatementResolver = require './c_assign_statement_resolver'

helpers = require './helpers'

resolve_type = (typelist, name)->
  scope = path:["resolve:#{name}"]
  return helpers.resolve_type(name, scope, typelist)
  #for t,i in typelist
    ## if the type matches, return the index in the typelist
    #return i if name == t.name
  ## If the type cannot be resolved, we have a problem
  #throw new Error("Cannot resolve type name: '#{typename}'")

class ScopeHelper
  constructor: (@parent=null)->
    @levels = [{}]
    @path = ["<root>"]

  push_level: (name)->
    @path.push name
    @levels.push {}

  pop_level: ->
    if @levels.length < 2
      throw new Error("Cannot remove any more levels from the ScopeList.")
    @path.pop()
    @levels.pop()


  with_level: (name, callback)->
    @add_level(name)
    callback()
    @remove_level()

  current: -> @levels[ @levels.length - 1 ]

  set: (key, val)->
    @current()[key] = val

  get: (key)->
    i = @levels.length
    while i > 0
      i--
      return @levels[i][key] if @levels[i][key]

    # Check any parent scope
    if @parent
      @parent.get(key)
    else
      null

class MethodListResolver
  constructor: (@pack, @normalized_package, @scoped)->
    # cache some things for legacy code
    @typelist = @normalized_package.typelist
    @method_lists = @normalized_package.method_lists
    @expressions = @normalized_package.expressions
    # create something to store the expressions that get generated
    @expressions = new ExpressionTreeList @typelist, @method_lists, @expressions

    # define the root scope
    scope = new ScopeHelper
    #
    for method_list in pack.method_lists
      target_name = method_list.type.name
      access = method_list.access
      target = @resolve_type target_name

      methods = []
      for method in method_list.methods
        methods.push @single_definition(method, target, scope)

      @method_lists.push { _type: "method_list", target: target, methods: methods, access: access }

    # go through each unbound method and compile them into the global
    # list
    unbound_methods = []
    for method in pack.unbound_methods
      unbound_methods.push @single_definition(method, null, scope)

    @method_lists.push { _type: "method_list", target: null, methods: unbound_methods, access: null }
    console.log 'unbound_methods:', unbound_methods

  single_definition: (method, target, scope)->
    resolver = new SingleDefinitionResolver( @normalized_package, target, scope )
    resolver.resolve( method )

  resolve_type: (name)-> resolve_type( @typelist, name )


class SingleDefinitionResolver
  # the package and the target (receiver) of this method
  constructor: (@pkg, @target, parent_scope)->
    # cache some things for legacy code
    @typelist = @pkg.typelist
    @method_lists = @pkg.method_lists
    @expressions = @pkg.expressions

    # the expression tree resolver
    @scope = new ScopeHelper( parent_scope )
    @expression_resolver = new ExpressionTreeResolver(@typelist, @method_list, @target, @scope)

    @resolvers =
      cassign: new CAssignStatementResolver
    resolver.parent = @ for k,resolver of @resolvers

  resolve: (method)->
    args = ({ name: a.name, type: @resolve_type(a.type) } for a in method.args)
    returns = ({ type: @resolve_type(r.name) } for r in method.returns)
    method_def = { name: method.name, args: args, returns: returns }
    #console.log "Method def:", method_def
    #for a in method.args
      #console.log "--- arg: ", a
    # add the arguments and returns to the scope
    for arg in args
      @scope.set( arg.name, _type: 'arg', type: arg.type, name: arg.name )
    # get the docs
    method_def.docs = method.docs
    # resolve the body
    method_def.body = @resolve_body method_def, method.body
    method_def

  resolve_body: (method_def, statement_list)->
    for s in statement_list
      switch s._type
        #when "cassign" then new CAssignStatementResolver().resolve( s )
        when "return" then { _type: "return", expr: @expression_resolver.resolve_tree(s.tree) }
        when "expression" then { _type: "expression", expr: @expression_resolver.resolve_tree(s.tree) }

        else
          resolver = @resolvers[s._type]
          resolver.target = @target
          resolver.resolve( s )

  resolve_type: (name)-> resolve_type( @typelist, name )

# Helper object to construct and resolve expression trees and put them in a linear
# array for easy referencing
class ExpressionTreeList
  constructor: (@typelist, @method_lists, @expressions)->

  add: (resolved_type)->
    idx = @expressions.length
    resolved_type = @resolver.resolve_tree tree
    @expressions.push resolved_type
    #idx
    resolved_type

module.exports = MethodListResolver
