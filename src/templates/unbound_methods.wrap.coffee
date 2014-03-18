
basics = include 'basics'
statements_ns = include 'statements'

statements = new statements_ns.StatementListWriter( pack.typelist, pack.method_lists )


line "#pragma once"
line "#include \"#{pack.name}_types.h\""

inline sep: ' ', ->
  inline sep: ' ', ->
    wrap start: 'namespace', end:'{', sep: '::', ->
      out pack.name

  inline ->
    unbound_methods = _.findWhere( pack.method_lists, target: null )
    return unless unbound_methods
    for method in unbound_methods.methods
      wrap no_inline: true, ->
        statements_ns.build_method(pack, statements, method, null, body: false)

  inline ->
    out "}"

