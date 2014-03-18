_ = require 'underscore'


# replace a proxy type in the typelist
replace_in_typelist = (typelist, name, with_what)->
  for t,i in typelist
    # if the type matches, return the index in the typelist
    continue unless name == t.name
    unless t._type == 'proxy'
      throw new Error("Only proxy types can be replaced in the typelist, #{JSON.stringify(t)} isnt a proxy")
    _.extend typelist[i], with_what
    return
  throw new Error("Cannot find proxy type '#{name}' in typelist: [#{(t.name for t in typelist).join(', ')}]")

# Get a types index in a typelist
resolve_type = (typename, current_scope, typelist)->
  # generate the full type name
  if _.isString(typename)
    return find_type_by_name( typename, current_scope, typelist )
  # the base name of the type
  base_type_name = typename.name
  # any extensions
  extensions = typename.extensions
  # get the qualified name of the type
  qualified_name = type_name_with_extensions( base_type_name, extensions )
  # find the base type
  base_type = find_type_by_name( base_type_name, current_scope, typelist )
  # check if the qualifier type exists
  qualified_type = find_type_by_name_nocheck( qualified_name, current_scope, typelist )
  # if not, add an entry to the typelist
  return qualified_type if qualified_type >= 0
  typelist.push { _type: "extended", name: qualified_name, public: false, base: base_type, extensions: extensions }
  return typelist.length - 1


# Find a type in the typelist by name
# or throw an error
find_type_by_name = (typename, current_scope, typelist)->
  res = find_type_by_name_nocheck(typename, current_scope, typelist )
  return res if res >= 0
  throw new Error("Cannot resolve type name: '#{typename}' inside '#{current_scope.path.join('/')}'\n\n  Available types: #{JSON.stringify _.pluck(typelist, "name")}")

find_type_by_name_nocheck = (typename, current_scope, typelist)->
  throw new Error("Tried to lookup undefined type name '#{current_scope.path.join('/')}'") unless typename
  for t,i in typelist
    # if the type matches, return the index in the typelist
    return i if typename == t.name
  -1

# Get a typename that contains all the extensions to a type
type_name_with_extensions = (name, extensions)->
  o = [ name ]
  for ext in extensions
    o.push switch ext._type
      when "array" then "[#{ext.size}]"
      when "pointer" then "*"
      when "reference" then "&"

  o.join('')

module.exports =
  resolve_type: resolve_type
  replace_in_typelist: replace_in_typelist
  find_type_by_name: find_type_by_name
  find_type_by_name_nocheck: find_type_by_name_nocheck
  type_name_with_extensions: type_name_with_extensions
