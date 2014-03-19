_ = require 'underscore'
winston = require 'winston'


expression_tree = require './tree_parser/expression_tree'

assert_token_group = ( token, group_name )->
  if token._group != group_name
    throw new Error("expected #{group_name}, got #{token._group} (#{token._type})")


as_json = (what)->
  switch
    when _.isBoolean(what) || _.isNumber(what) || _.isString(what) then what
    when _.isArray(what) then ( as_json(w) for w in what )
    when _.isObject(what)
      # serialize via the build-in stuff
      if what.as_json
        res = what.as_json()
        as_json(res)
      else
        o = {}
        ( o[k] = as_json(v) for k,v of what )
        o

class Package

  constructor: (@name)->
    @symbols = {}
    @types = {}
    @method_lists = []
    @unbound_methods = []

  classes: ->
    #_.where( @symbols, type:
  as_json: -> as_json({ name: @name, types: @types, symbols: @symbols, method_lists: @method_lists, unbound_methods: @unbound_methods })

# Base class for serialization
class JsonSerializable
  as_json: (data...)-> _.extend( data...)

# Helper base class to serialize stuff with a name
class JsonSerializableWithName extends JsonSerializable
  as_json: (data...)-> super({ name: @name }, data...)

# Base class for any type declaration package
class TypeBase extends JsonSerializableWithName
  package: null
  parse: (decl)->
  set_docs: (docs)-> @docs = docs
  as_json: (data...)-> super({_resolved: true, docs: @docs}, data...)

# A type class for yet unresolved types
class ProxyType extends TypeBase
  constructor: (@name, decl)->
    @package = null
    @resolved = false

    if decl and decl.extensions
      # add all the extensions
      @extensions = for ext in decl.extensions
        switch ext._type
          when "POINTER" then { _type: "pointer" }
          when "REFERENCE" then { _type: "reference" }
          when "ARRAY" then { _type: "array", size: parseInt(ext.size) }
          else
            throw new Error("Unknown type extension: #{ext._type} - decl: #{decl}")

  as_json: -> super( _resolved: false, extensions: @extensions )


# Common base class for Class and Struct
class StructuredData extends TypeBase
  # Parse the field data
  make_fields: (layout)->
    @fields = []
    for field in layout.fields
      f = new Field(field)
      @fields.push f

  # Hook the field parsing
  parse: (as)-> super(as); @make_fields( as.fields )
  as_json: (data)-> super( fields: @fields, data )

class Class extends StructuredData
  constructor: (@name)->
  as_json: -> super( _type: 'class' )
  parse: (as)-> super(as)

class Struct extends StructuredData
  constructor: (@name)->
  parse: (as)-> super(as)
  as_json: -> super( _type: 'struct')

class Interface extends TypeBase
  constructor: (@name)->
    @methods = new MethodList( null, null )
  as_json: -> super( _type: 'interface', methods: @methods.methods )
  parse: (as)->
    super(as)
    @methods.parse as.method_list.methods
    #console.log as.method_list




# A single type alias
class Alias extends TypeBase
  constructor: (@name)->
  parse: (as)->
    super(as)
    @original = new ProxyType( as.original.name.text, as )

  as_json: -> super( _type: 'alias', original: @original )

# A single type alias
class CType extends TypeBase
  constructor: (@name)->
  parse: (as)->
    super(as)
    @c_name = as.c_name.name.text

  as_json: -> super( _type: 'ctype', c_name: @c_name )

# A struct or class data field
class Field extends JsonSerializableWithName
  constructor: (data)->
    @name = data.name.text
    @docs = data.docs
    @type = new ProxyType( data.type.name.text, data.type )

  as_json: -> super( type: @type, docs: @docs )



class MethodArgument extends JsonSerializableWithName
  constructor: (@name)->
  as_json: -> super( type: @type )
  parse: (decl)->
    @type = new ProxyType( decl.type.name.text, decl.type )

class Method extends JsonSerializableWithName
  constructor: (@name )->
  as_json: -> super( args: @args, returns: @returns, body: @body, docs: @docs )

  parse: (decl)->
    @args = []
    @returns = []
    @body = []
    @docs = decl.docs
    # if the method has arguments, add them
    for arg in decl.func.args.list
      m_arg = new MethodArgument( arg.decl.name.text )
      m_arg.parse( arg.decl )
      @args.push m_arg

    # add the return types
    for ret in decl.func.returns.list
      m_arg = new ProxyType( ret.name.text, ret )
      #m_arg.parse( arg.decl )
      @returns.push m_arg

    if decl.func.body
      for statement in decl.func.body.statements
        s = new Statement( statement )
        @body.push s


# A simple list of methods
class MethodList extends JsonSerializable
  constructor: (@type, @access)->
    @methods = []
  as_json: -> super( type: @type, access: @access, methods: @methods )

  parse: (methods)->
    for method in methods
      m = new Method( method.name.text )
      m.parse method
      @methods.push m



class Statement extends JsonSerializable
  as_json: -> super( @attrs, _type: @_type, tree: @tree )
  constructor: (tree)->
    @tree = {}
    @attrs = {}
    @processTree tree


  processTree: (tree, output={})->

    assert_token_group tree, 'statement'
    _t = tree._type
    switch _t
      # handle individual stuff
      when "RETURN" then @_type = "return"; @tree = expression_tree.make(tree.expr)
      when "EXPR" then @_type = "expression"; @tree = expression_tree.make(tree.expr)
      when "CASSIGN"
        @_type = "cassign"
        @attrs.name = tree.name.text
        @tree = expression_tree.make(tree.expr)

      else
        winston.error "unknown token type: #{_t}", t
        throw new Error("Unknown statement token type: #{_t}")

      # Handle groups
      #else
        #switch
          #when _t in ["EXPR"] then @_type = "expression"; @tree = expression_tree.make(tree.expr)


type_base_map = CLASS: Class, STRUCT: Struct, ALIAS: Alias, CTYPE: CType, INTERFACE: Interface

# Get a units package name
package_name_for_unit = (unit)->
  unit.package.name.text


# Get a types key from the declaration.
# This should handle autoconstructed and descriptive
# keys
get_type_key = (decl)->
  throw new Error("Cannot get key of undefined decl") unless decl
  return decl.klass.key if decl.klass
  return decl._type if decl._type
  throw new Error("Unknown type #{decl}")

make_type_instance = (pkg, name, decl)->
  key = decl.definition._type
  klass = type_base_map[key]
  throw new Error("Unknown type to instantiate: #{key}") unless klass
  type_instance = new klass(name)
  type_instance.set_docs( decl.docs )
  type_instance.package = pkg
  type_instance

add_declarations_to_package = (pkg, declarations)->
  # Add the declarations
  for decl in declarations
    switch decl._type
      when 'TYPEDECL'
        type_name = decl.name.text
        type_instance = make_type_instance( pkg, type_name, decl )
        # try to add the documentation
        type_instance.parse decl.definition
        # store the type
        pkg.types[type_name] = type_instance

      # Method lists
      when 'METHODS'
        type_name = decl.name.text
        # since the type may not yet have been defined, proxy it
        type_instance = new ProxyType( type_name )
        method_list = new MethodList( type_instance, decl.access )
        method_list.parse decl.body
        pkg.method_lists.push method_list

      # Unbound methods 
      when 'UNBOUND_METHOD'
        method = new Method( decl.name.text )
        method.parse decl
        pkg.unbound_methods.push method

      else
        throw new Error( "Unknown declaration type: '#{decl._type}'" )

  pkg




package_from_units = (units)->
  # fail on empty packages
  return null if units.length == 0
  # create the package
  package_name = package_name_for_unit units[0]
  pkg = new Package(package_name)
  # Add all units to the package
  for unit in units
    # check if the unit is in the valid package
    unit_package_name = package_name_for_unit unit
    unless unit_package_name == package_name
      throw new Error("Package name '#{unit_package_name}' differs from '#{package_name}'")
    # We are sure we have the right package
    add_declarations_to_package( pkg, unit.contents.declarations )

  # return the fresh package
  pkg

module.exports =
  Class: Class
  Package: Package
  from_units: package_from_units
