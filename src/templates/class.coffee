util = require '../util'

module.exports = (c, input)->

  klass = input.class
  pack = input.package
  type_idx = input.idx

  c.wrapped "{", "}", "namespace", pack.name, ->
    c.wrapped "{", "};", "class", klass.name, ->
      for field in klass.fields
        field_type = pack.typelist[field.type]
        c.tokens util.type_name(field_type), field.name, ';'

      for method_list in input.method_lists
        c.indented "#{method_list.access}:", ->
          for method in method_list.methods
            args = []
            for a,i in method.args
              arg_type = pack.typelist[a.type]
              args.push( util.type_name( arg_type ), a.name )
              args.push ',' if i < (method.args.length - 1)

            ret = ["void"]
            if method.returns.length > 0
              ret = []
              for r, i in method.returns
                ret.push util.type_name(pack.typelist[r.type])

              if method.returns.length > 1
                ret = ["multi", "<", ret..., ">"]

            ret = util.array_join( ret, ',' )
            method_name = util.class_method_name( klass, method.name )
            c.tokens ret..., method_name, '(', args..., ')', ';'
