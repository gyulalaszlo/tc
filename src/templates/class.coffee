module.exports = (c, obj)->
  `with(obj||{}) {`

  c.braces "class #{type.name}", ->
    c.l "// fields"
    for field in type.as.layout.fields
      c.tokens field.type.name, field.name, ";"

    for method_set in methods
      c.indent "#{method_set.access}:", ->
        for method in method_set.body
          args = null
          args = method.func.args.to_c() if method.func.args.to_c
          args = c.wrapped( "(", ")", args )
          c.tokens method.return_type(), method.real_name(), args,  ';'

  `}`
