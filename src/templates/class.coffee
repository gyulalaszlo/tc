module.exports = (c, obj)->
  `with(obj||{}) {`

  c.wrapped "{", "};", "class", type.name.text, ->
    for field in type.as.layout.fields
      c.l field.type.name, field.name, ";"

    for method_set in methods
      c.indented "#{method_set.access}:", ->
        for method in method_set.body
          args = null
          args = method.func.args.to_c() if method.func.args.to_c
          args = c.wrap( "(", ")", args )
          c.l method.return_type(), method.real_name(), args,  ';'

  `}`
