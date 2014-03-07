
typedef_inner = (name, original)->
  wrap sep: " ", contents: [ "typedef", typename(original), name ]

field_list = (fields)->
  for field in fields
    field_type = pack.typelist[field.type]
    log field
    wrap ->
      wrap( sep: ' ', -> out(type_name(field_type), field.name) )
      out ';'


wrap start:"namespace {", end:'}', ->
  log "hello"
  not_published = _.chain( pack.typelist ).where({ public: false })
  log not_published

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
  klasses = for t in not_published.where( _type: "class").value()
    #name_wrap = wrap sep: ' ', ['class', type_name(t) ]
    wrap start: "class #{type_name(t)} {", end: '};', ->
      #wrap start:"{", end:"};", before: wrap( ["class" ], type_name(t), ->
      field_list( t.fields )
      #
  klasses

