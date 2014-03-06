
# Create and Assign statements need their type deduced
class CAssignStatementResolver
  resolve: (t)->
    # get the initializer expression
    initializer_expression = @parent.expression_resolver.resolve_tree(t.tree) 
    throw new Error("Cannot resolve right hand side of Create and Assign statement. - #{JSON.stringify(t)}") unless initializer_expression
    console.log initializer_expression
    # this tells us our type
    type = initializer_expression.type
    throw new Error("Cannot resolve type for left hand side of Create and Assign statement. - #{JSON.stringify(initializer_expression)}") unless type

    var_name = t.name
    # add to the scope
    @parent.scope.set var_name, { _type: "var", type: type, name: var_name }
    { _type: "cassign", name: var_name, expr: initializer_expression, type: type  }

module.exports = CAssignStatementResolver
