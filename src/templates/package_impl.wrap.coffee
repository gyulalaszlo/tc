
typedef_inner = (name, original)->
  wrap sep: " ", contents: [ "typedef", typename(original), name ]

field_list = (fields)->
  for field in fields
    field_type = pack.typelist[field.type]
    wrap ->
      wrap( sep: ' ', -> out(type_name(field_type), field.name) )
      out ';'

class TypenameLookup
  constructor: (@typelist)->
  c_name: (type_id)-> type_name( @typelist[type_id] )


build_method_signature = (pack, method, target=null)->
  types = new TypenameLookup( pack.typelist )
  # the arg list builder fn
  arg_list_builder = (a)-> { type: type_name(pack.typelist[a.type]), name:a.name }
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
  wrap ->
    wrap sep: ' ',->
      out ret...
      wrap sep: '::', ->
        out name...
      out '('
      wrap sep:', ', ->
        wrap sep: ' ', ->
          for arg in args
            out arg.type
            out arg.name
      out ')'



wrap start:"namespace {", end:'}', ->
  not_published = _.chain( pack.typelist ).where({ public: false })

  # first the aliases, so we are safe
  #for t in not_published.where( _type: "alias").value()
    #log "hello", t
    #original = pack.typelist[t.original]
    #wrap sep: " ", contents: typedef_inner(t.name, original )
    ##c.tokens "typedef", type_name(original), t.name, ";"

  # declare the public structs used
  #for t in not_published.where( _type: "struct").value()
    #wrap "{", "};", "struct", type_name(t), ->
      #field_list(c, pack, t.fields )

  # forward-declare the classes
  for t in not_published.where( _type: "class").value()
    #name_wrap = wrap sep: ' ', ['class', type_name(t) ]
    wrap start: "class #{type_name(t)} {", end: '};', ->
      #wrap start:"{", end:"};", before: wrap( ["class" ], type_name(t), ->
      field_list( t.fields )

#statements = new StatementListWriter( pack.typelist, pack.method_lists )
wrap start:"namespace #{pack.name } {", end:"}", ->
  # put the not-inlined method bodies
  for method_list in pack.method_lists
    target = pack.typelist[method_list.target]

    for method in method_list.methods
      wrap sep: ' ', ->
        build_method_signature(pack, method, target)
        wrap start: '{', end: '}', ->
          out "/**/"
        #wrap "{", "}", build_method_signature(pack, method, target)..., ->

        #o = []
        #statements.list( method.body, o )
        #c.tokens o...
        #for statement in method.body
          #c.tokens JSON.stringify(statement)

