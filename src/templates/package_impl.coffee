_ = require 'underscore'
util = require '../util'

type_name = util.type_name

field_list = (c, pack, fields)->
  for field in fields
    field_type = pack.typelist[field.type]
    c.tokens type_name(field_type), field.name, ';'

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
          o.push( @types.c_name(s.type), s.name, '=' )
          @expressions.tree( s.expr, o )
          o.push ';'


        when "expression"
          @expressions.tree( s.expr, o )
          o.push ';'


        when 'return'
          o.push( "return" )
          @expressions.tree( s.expr, o )
          o.push ';'

        else
          throw new Error( "Unknown statement type: '#{s._type}'" )
    # return the mapped value
    o



class ExpressionTreeWriter
  constructor: (@typelist, @method_lists)->

  tree: (expr, o=[])->
    switch expr._type
      when "this"
        o.push "this"

      when "variable"
        o.push expr.name

      when "literal"
        o.push JSON.stringify( expr.value )

      when "member"
        @tree( expr.base, o )
        @access_chain( expr.access_chain, o ) 

      else
        _type = expr._type
        switch
          when _type in ["assignment_expr"]
            @tree( expr.a, o )
            o.push expr.op
            @tree( expr.b, o )
          else
            throw new Error( "Unknown expresssion type: '#{expr._type}'" )

    o

  access_chain: (chain, o)->
    for chain_el in chain
      switch chain_el._type

        # simple property access
        when "property"
          o.push '.', chain_el.name


build_method_signature = (pack, method, target=null)->
  types = new TypenameLookup( pack.typelist )
  # the arg list builder fn
  arg_list_builder = (a)-> [ type_name(pack.typelist[a.type]), a.name ]
  # the return type builder fn
  ret_type_builder = (a)-> [ type_name(pack.typelist[a.type]) ]
  # preload the stuff
  name = [method.name]
  # add the target to the name
  name = [ type_name( target )].concat(name) if target
  # make the arg and return lists
  args =  _.flatten( util.array_join( _.map( method.args, arg_list_builder ), ',' ) )
  ret = _.map( method.returns, ret_type_builder )
  [ ret, name.join('::'), '(', args..., ')'  ]

module.exports = (c, pack)->

  c.wrapped "{", "}", "namespace", ->


    # find all the hidden types
    not_published = _.chain( pack.typelist ).where({ public: false })

    # first the aliases, so we are safe
    for t in not_published.where( _type: "alias").value()
      original = pack.typelist[t.original]
      c.tokens "typedef", type_name(original), t.name, ";"

    # declare the public structs used
    for t in not_published.where( _type: "struct").value()
      c.wrapped "{", "};", "struct", type_name(t), ->
        field_list(c, pack, t.fields )

    # forward-declare the classes
    for t in not_published.where( _type: "class").value()
      c.wrapped "{", "};", "class", type_name(t), ->
        field_list(c,  pack, t.fields )



  statements = new StatementListWriter( pack.typelist, pack.method_lists )
  c.wrapped "{", "}", "namespace", pack.name, ->
    # put the not-inlined method bodies
    for method_list in pack.method_lists
      target = pack.typelist[method_list.target]
      c.tokens "\n/////// Method list: #{target.name}\n"

      for method in method_list.methods
        c.wrapped "{", "}", build_method_signature(pack, method, target)..., ->

          o = []
          statements.list( method.body, o )
          c.tokens o...
          #for statement in method.body
            #c.tokens JSON.stringify(statement)


#util = require '../util'

#module.exports = (c, input)->

  #klass = input.class
  #pack = input.package
  #type_idx = input.idx

  #c.wrapped "{", "}", "namespace", pack.name, ->
    #c.wrapped "{", "};", "class", klass.name, ->
      #for field in klass.fields
        #field_type = pack.typelist[field.type]
        #c.tokens util.type_name(field_type), field.name, ';'

      #for method_list in input.method_lists
        #c.indented "#{method_list.access}:", ->
          #for method in method_list.methods
            #args = []
            #for a,i in method.args
              #arg_type = pack.typelist[a.type]
              #args.push( util.type_name( arg_type ), a.name )
              #args.push ',' if i < (method.args.length - 1)

            #ret = ["void"]
            #if method.returns.length > 0
              #ret = []
              #for r, i in method.returns
                #ret.push util.type_name(pack.typelist[r.type])

              #if method.returns.length > 1
                #ret = ["multi", "<", ret..., ">"]

            #ret = util.array_join( ret, ',' )
            #method_name = util.class_method_name( klass, method.name )
            #c.tokens ret..., method_name, '(', args..., ')', ';'

