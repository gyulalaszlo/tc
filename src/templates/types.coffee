_ = require 'underscore'
util = require '../util'

type_name = util.type_name


module.exports = (c, pack)->

  c.wrapped "{", "}", "namespace", pack.name, ->

    # first the aliases, so we are safe
    for t in _.where( pack.typelist, _type: "alias", public: true )
      original = pack.typelist[t.original]
      c.tokens "typedef", type_name(original), t.name, ";"

    # declare the public structs used
    for t in _.where( pack.typelist, _type: "struct", public: true )
      c.wrapped "{", "};", "struct", t.name, ->
        for field in t.fields
          field_type = pack.typelist[field.type]
          c.tokens type_name(field_type), field.name, ';'

    # forward-declare the classes
    for t in _.where( pack.typelist, _type: "class", public: true )
      c.tokens "class", t.name, ';'

