basics = include 'basics'

typedef_inner = (name, original)->
  wrap sep: " ", contents: [ "typedef", type_name(original), name ]

class TypenameLookup
  constructor: (@typelist)->
  c_name: (type_id)-> type_name( @typelist[type_id] )


class StatementListWriter
  constructor: (@typelist, @method_lists)->
    @expressions = new ExpressionTreeWriter( @typelist, @method_lists )
    @types = new TypenameLookup( @typelist )

  list: (statement_list, o=[])->
    for s in statement_list
      switch s._type

        when "cassign"
          # the local variable init
          inline =>
            inline sep: ' ', =>
              inline =>
                out @types.c_name(s.type)
              out s.name
              out '='

              #o.push( @types.c_name(s.type), s.name, '=' )
              inline =>
                @expressions.tree( s.expr, o )
            out ';'


        when "expression"
          inline =>
            @expressions.tree( s.expr, o )
            out ';'


        when 'return'
          inline =>
            inline sep: ' ', =>
              out 'return'
              inline =>
                @expressions.tree( s.expr, o )
            out ';'

        else
          throw new Error( "Unknown statement type: '#{s._type}'" )
    # return the mapped value
    o



class ExpressionTreeWriter
  constructor: (@typelist, @method_lists)->

  tree: (expr, o=[])->
    switch expr._type
      when "this"
        out 'this'
        #o.push "this"

      when "variable"
        out expr.name
        #o.push expr.name

      when "literal"
        out JSON.stringify( expr.value )

      when "member"
        @tree( expr.base, o )
        @access_chain( expr.access_chain, o ) 

      else
        _type = expr._type
        switch
          when _type in ["assignment_expr"]
            inline sep: ' ', =>
              inline =>
                @tree( expr.a, o )
              out expr.op
              inline =>
                @tree( expr.b, o )
          else
            throw new Error( "Unknown expresssion type: '#{expr._type}'" )

    o

  access_chain: (chain, o)->
    inline =>
      for chain_el in chain
        switch chain_el._type

          # simple property access
          when "property"
            inline ->
              out '.'
              out chain_el.name
          when 'array'
            inline sep: ' ', =>
              out '['
              inline =>
                @tree( chain_el.expr, o )
              out ']'

build_method = (pack, statements, method, target=null, opts={})->
  _.defaults opts, body: true
  types = new TypenameLookup( pack.typelist )
  # the arg list builder fn
  arg_list_builder = (a)-> { type: pack.typelist[a.type], name:a.name }
  # the return type builder fn
  ret_type_builder = (a)-> [ type_name(pack.typelist[a.type]) ]
  # preload the stuff
  name = [method.name]
  # add the target to the name
  name = [ type_name( target )].concat(name) if target
  # make the arg and return lists
  #
  args =  _.map( method.args, arg_list_builder )
  ret = _.map( method.returns, ret_type_builder )
  # make the wraps
  inline no_inline: true, ->
    basics.docstring( method )
  inline sep: ' ', ->
    inline ->
      inline sep: ' ', ->
        out if ret.length > 0 then ret else 'void'
        inline sep: '::', ->
          out name...
      inline sep: ' ', ->
        wrap start: '(', end: ')', ->
          inline ->
            inline sep: ', ', ->
              for arg in args
                inline sep: ' ', ->
                  #log arg, method
                  variable_with_type arg.type, arg.name
                  #out arg.type, arg.name

    if opts.body
      wrap sep: ' ', ->
        inline sep: ' ', start: '{', end: '}', ->
          statements.list( method.body )
    else
      out ';'

exports 'statements',
  #field_list: field_list
  #docstring: docstring
  build_method: build_method
  StatementListWriter: StatementListWriter
