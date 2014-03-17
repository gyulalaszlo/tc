
docstring = (obj)->
  text = if _.isString( obj ) then obj else obj.docs
  return unless text
  text = _s.strip( text )
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
      variable_with_type( field_type, field.name )
      #out(type_name(field_type), field.name)
    out ';'

# Output a declaration for a "<type> <name>" pair
# that matches the C type declaration standard
# (pointers, references, arrays should be declared
# in the correct way)
variable_with_type = (type, name)->

  resolve_base_type = (base_type)->
    tname = base_type._type
    exported_modifiers = []
    switch
      # CTYPEs are output directly
      when tname == 'ctype' then out base_type.raw
      # ALIAS, CLASS and STRUCT types are referenced 
      # by their names
      when tname in ['alias', 'class', 'struct' ] then out base_type.name
      # EXTENDED types
      when tname == 'extended'
        # add the extensions passed from the base type
        # to our exported extensions
        resolved_base_type =  pack.typelist[base_type.base]
        child_exports =  resolve_base_type( resolved_base_type )
        exported_modifiers  = exported_modifiers.concat( child_exports )
        for ext in base_type.extensions
          switch ext._type
            when 'array'
              exported_modifiers.push "[", ext.size.toString(), ']'
            when 'pointer' then out '*'
            when 'reference' then out '&'
      # 
      else
        throw new Error("Cannot output 'variable_with_type' type: #{tname}")
    return exported_modifiers
        

  
  # the topmost wrap of the type
  inline sep: ' ', ->
    passed_extensions = []
    # the type name wrap
    wrap ->
      passed_extensions = resolve_base_type( type )
    # the ver name wrap
    wrap ->
      out name
      for e in passed_extensions
        out e
      
# declare a list of fields
field_list = (fields)->
  for field in fields
    field_decl( field )

exports 'basics',
  field_list: field_list
  docstring: docstring
