_ = require 'underscore'

class ExpressionTreeResolver
  constructor: (@typelist, @method_list, @target, @scope)->
    @resolvers =
      this: new ThisResolver
      binary_expression: new BinaryExpressionResolver
      literal_expression: new LiteralExpressionResolver
      variable_expression: new VariableExpressionResolver
      member_expression: new MemberExpressionResolver
      call_member: new MemberCallExpressionResolver
    # assign the parents for usage
    resolver.parent = @ for k,resolver of @resolvers

  resolve_tree: (t)->
    resolver = @resolvers[t._type]
    throw new Error("Unknown expression type: #{ t._type }") unless resolver
    res = resolver.resolve(t)
    throw new Error("Cannot resolve type for expression tree: #{ JSON.stringify(res) }") unless res.type
    res

class BinaryExpressionResolver
  resolve: (t)->
    # resolve both operands
    a = @parent.resolve_tree(t.a)
    b = @parent.resolve_tree(t.b)

    type = -1
    type = a.type if a.type == b.type
    # check the op
    op = t.op
    res = switch
      when op in ["=", "+=", "-="]
        { _type: "assignment_expr", op: op, a: a, b: b }
      when op in ["+", "-", "/", "*"]
        { _type: "binary_expr", op: op, a: a, b: b }
      else
        throw new Error("Unknown BINARY operator: #{ op }")
    # pass the type
    res.type = type
    res

node_factories =
  # common helper for ThisResolver and ThisAccessResolver
  this: ( type_id )-> { _type: "this", type: type_id }

  # common helper for outputting a member access node
  member_access: (base, access_chain, type_id )->
    { _type: "member", base: base, access_chain: access_chain, type: type_id  }

  property_access: (name)-> { _type: "property", name: name  }

class ThisResolver
  resolve: (t)-> { _type: "this", type: @parent.target }
    #node_factories.this( @parent.target )


class LiteralExpressionResolver
  resolve: (t)-> { _type: "literal", value: t.value, type: -1  }

class MemberExpressionResolver
  resolve: (t)->
    base = @parent.resolve_tree(t.base)
    access_chain = []
    # When we start with a "this" access, add the @access to
    # the access chain.
    if base._type == "member"
      # use the original base
      base = base.base
      # and copy over the old access chain
      access_chain.concat base.access_chain

    # Lookup the base type and store it as the
    # current type
    current_type_id = base.type
    current_type = @parent.typelist[current_type_id]

    # Iterate through the access chain, check and resolve
    # each access's type
    for chain_el in t.access_chain
      switch chain_el._type
        when "property_access"
          prop_name = chain_el.name
          result = node_factories.property_access( chain_el.name )
          # check if the type has any such properties
          field = _.findWhere( current_type.fields, name: prop_name )
          switch
            when field
              result.type = current_type_id = field.type
            else
              #method_lists = _.where( @parent.method_lists, target: current_type_id )
              #matching_methods
              #method = _findWhere( current_type.fields, name: prop_name )
              #console.log method
              throw new Error("Method lookup not implemented")

          current_type = @parent.typelist[current_type_id]
          access_chain.push( result )


    node_factories.member_access( base, access_chain, current_type_id )





class VariableExpressionResolver
  resolve: (t)->
    var_name = t.name
    from_scope = @parent.scope.get var_name
    unless from_scope
      throw new Error("Cannot resolve '#{var_name}'")

    { _type: "variable", name: t.name, type: from_scope.type  }

class MemberCallExpressionResolver
  resolve: (t)-> { _type: "member_call", member: t.member ,args: t.args, tail: t.tail  }


module.exports = ExpressionTreeResolver
