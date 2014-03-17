
basics = include 'basics'

line "#pragma once"

inline ->
  inline sep: ' ', ->
    wrap start: 'namespace', end:'{', sep: '::', ->
      out pack.name

  wrap ->
    for t in published.where( _type: "alias").value()
      inline ->
        original = pack.typelist[t.original]
        inline sep: ' ', ->
          out "typedef", type_name(original), t.name
        out ';'

    for t in published.where( _type: "struct").value()
      inline ->
        inline ->
          basics.docstring( t )
        inline sep: ' ', ->
          inline sep: ' ', ->
            out 'struct', type_name(t)
          wrap start: "{", end: '};', sep: ' ', ->
            basics.field_list( t.fields )

    for t in published.where( _type: "class").value()
      inline ->
        inline ->
          basics.docstring( t )
        inline sep: ' ', ->
          out 'class', type_name(t)
        out ';'

  inline ->
    out "}"

