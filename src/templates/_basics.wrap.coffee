
docstring = (obj)->
  text = if _.isString( obj ) then obj else obj.docs
  return unless text
  wrap sep: ' ', no_inline: true, ->
    out "/**"
    inline -> out text
    out "*/"

# Declare a single field
field_decl = (field)->
  field_type = pack.typelist[field.type]
  docstring( field )
  inline ->
    wrap sep: ' ', ->
      out(type_name(field_type), field.name)
    out ';'


# declare a list of fields
field_list = (fields)->
  for field in fields
    field_decl( field )

exports 'basics',
  field_list: field_list
  docstring: docstring
