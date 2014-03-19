_ = require 'underscore'
winston = require 'winston'

json_serializable = require './json_serializable'
helpers = require './helpers'

make_expression_tree = (t)->
  helpers.assert_token_group t, 'expr'
  _type = t._type
  switch _type
    # Access chaining
    when "THIS" then new ThisExpression
    when "THIS_ACCESS" then new ThisAccessExpression( t.name )
    when "CALL" then new CallExpression( t.base, t.tail )
    when "CALL_MEMBER" then new CallMemberExpression( t.member, t.args, t.tail )
    when "PROPERTY_ACCESS" then new PropertyAccessExpression( t.name )
    when "ARRAY_ACCESS" then new ArrayAccessExpression( t.name )
    when "CALL_CALLABLE" then new CallCallableExpression( t.args )
    # others
    when "MEMBER" then new MemberExpression( t.base, t.access_chain )
    when "VARIABLE" then new VariableExpression(  t.name )
    when "LITERAL" then new LiteralExpression( t.value.type, t.value.value )

    else
      switch
        when _type in ["ADD", "MUL", "SHITF", "RELATIONAL", "EQ", "ASSIGN"]
          new BinaryExpression( t.op, t.a, t.b )

        when _type in ["NEW"]
          new UnaryExpression( t.op, t.a )

        else
          winston.error "unknown token type: #{_type}", t
          winston.error JSON.serialize( t )
          throw new Error("Unknown expression token type: #{_type}")

out_factories =
  this: ()-> { _type: 'this' }

  member_expression: (base, access_chain)->
      {_type: 'member_expression', base: base, access_chain: access_chain }

  property_access: (name)-> { _type: 'property_access', name: name }
  array_access: (name)-> { _type: 'array_access', name: name }


class ThisExpression extends json_serializable.base
  as_json: -> super(out_factories.this())
  constructor: ->

# Eliminate syntactic sugar:
# Rewrite this_access to a member access on this.
class ThisAccessExpression extends json_serializable.base
  as_json: -> super( @member_expression )
  constructor: ( name )->
    @name = name
    @member_expression = out_factories.member_expression(
        out_factories.this(),
        [out_factories.property_access( @name )]
    )

class CallExpression extends json_serializable.base
  as_json: -> super( _type: 'call', base: @base, tail: @tail )
  constructor: (base, tail )->
    @base = make_expression_tree( base )
    @tail = (make_expression_tree( t ) for t in tail )

class CallMemberExpression extends json_serializable.base
  as_json: -> super( _type: 'call_member', member: @member, args: @args, tail:@tail )
  constructor: (member, args, tail )->
    @member = make_expression_tree( member )
    @args = (make_expression_tree( arg ) for arg in args)
    @tail = if tail then (make_expression_tree( arg ) for arg in tail) else []

class CallCallableExpression extends json_serializable.base
  as_json: -> super( _type: 'call_callable', args: @args )
  constructor: (args )->
    @args = (make_expression_tree( arg ) for arg in args)

class MemberExpression extends json_serializable.base
  as_json: -> super( out_factories.member_expression( @base, @access_chain ))
  constructor: (base, access_chain )->
    @base = make_expression_tree( base )
    @access_chain = (make_expression_tree( a ) for a in access_chain)
    #@access_chain = a


class PropertyAccessExpression extends json_serializable.base
  as_json: -> super( out_factories.property_access(@name) )
  constructor: ( @name )->

class ArrayAccessExpression extends json_serializable.base
  as_json: -> super( out_factories.array_access( make_expression_tree( @name )) )
  constructor: ( @name )->

class VariableExpression extends json_serializable.base
  as_json: -> super( _type: 'variable_expression', name: @name )
  constructor: (@name )->


class LiteralExpression extends json_serializable.base
  as_json: -> super( _type: 'literal_expression', type: @type, value: @value )
  constructor: ( @type, @value )->


class UnaryExpression extends json_serializable.base
  as_json: -> super( _type: 'unary_expression', op: @op, a: @a )
  constructor: (@op, a )->
    @a = make_expression_tree(a)


class BinaryExpression extends json_serializable.base
  as_json: -> super( _type: 'binary_expression', op: @op, a: @a, b: @b )
  constructor: (@op, a, b)->
    @a = make_expression_tree(a)
    @b = make_expression_tree(b)


class Expression extends json_serializable.base
  as_json: -> super( _type: 'expression', tree: @tree, op: @op, a: @a, b: @b )

  constructor: (tree)->
    @op = null
    @processTree tree

  processTree: (tree)->
    console.log "expr"
    console.log "--->", tree._group, tree._type
    if tree.op
      @op = tree.op
      console.log "op:", tree.op

    if tree.a
      console.log "A -> "
      @a = new Expression( tree.a )

    if tree.b
      console.log "B -> "
      @b = new Expression( tree.b )
    console.log "<---", tree._group, tree._type


module.exports =
  make: make_expression_tree

