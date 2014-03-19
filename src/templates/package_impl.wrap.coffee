
basics = include 'basics'

statements_ns = include 'statements'

statements = new statements_ns.StatementListWriter( pack.typelist, pack.method_lists )

line "#include \"#{pack.name}_types.h\""

# add included classes from the current package
for klass in published.where( _type: "class" ).value()
  line "#include \"#{_s.underscored( klass.name )}.h\""


inline  ->
  inline ->
    inline sep: ' ', ->
      out 'namespace', '{'

    wrap ->

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

      # declare the classes
      for t in not_published.where( _type: "class").value()
        inline ->
          basics.docstring( t  )
          inline sep: ' ', ->
            out 'class', type_name(t)
          inline ->
            wrap start: "{", end: '};', sep: ' ', ->
              basics.field_list( t.fields )

    inline ->
      out "}"


  inline ->
    inline sep: ' ', ->
      wrap start: 'namespace', end:'{', sep: '::', ->
        out pack.name

    wrap no_inline: true, ->
      # put the not-inlined method bodies
      for method_list in pack.method_lists
        target = pack.typelist[method_list.target]
        for method in method_list.methods
          statements_ns.build_method(pack, statements, method, target)

    inline ->
      out "}"

