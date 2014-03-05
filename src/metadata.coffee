_ = require 'underscore'
winston = require 'winston'

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

  classes: ->
    #_.where( @symbols, type:
  as_json: -> as_json({ name: @name, types: @types, symbols: @symbols, method_lists: @method_lists })

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
  as_json: (data...)-> super({_resolved: true}, data...)

# A type class for yet unresolved types
class ProxyType extends TypeBase
  constructor: (@name)->
    @package = null
    @resolved = false
  as_json: -> super( _resolved: false )


# Common base class for Class and Struct
class StructuredData extends TypeBase
  # Parse the field data
  make_fields: (layout)->
    @fields = []
    for field in layout.fields
      f = new Field(field)
      @fields.push f

  # Hook the field parsing
  parse: (as)-> @make_fields( as.fields )
  as_json: (data)-> super( fields: @fields, data )

class Class extends StructuredData
  constructor: (@name)->
  as_json: -> super( _type: 'class' )
  parse: (as)-> super(as)

class Struct extends StructuredData
  constructor: (@name)->
  parse: (as)-> super(as)
  as_json: -> super( _type: 'struct')




# A single type alias
class Alias extends TypeBase
  constructor: (@name)->
  parse: (as)->
    @original = new ProxyType( as.original.name.text )

  as_json: -> super( _type: 'alias', original: @original )

# A single type alias
class CType extends TypeBase
  constructor: (@name)->
  parse: (as)->
    @c_name = as.c_name.name.text

  as_json: -> super( _type: 'ctype', c_name: @c_name )

# A struct or class data field
class Field extends JsonSerializableWithName
  constructor: (data)->
    @name = data.name.text
    @type = new ProxyType( data.type.name.text )

  as_json: -> super( type: @type )



class MethodArgument extends JsonSerializableWithName
  constructor: (@name)->
  as_json: -> super( type: @type )
  parse: (decl)->
    @type = new ProxyType( decl.type.name.text )

class Method extends JsonSerializableWithName
  constructor: (@name )->
  as_json: -> super( args: @args, returns: @returns, body: @body )

  parse: (decl)->
    @args = []
    @returns = []
    @body = []
    # if the method has arguments, add them
    for arg in decl.func.args.list
      m_arg = new MethodArgument( arg.decl.name.text )
      m_arg.parse( arg.decl )
      @args.push m_arg

    # add the return types
    for ret in decl.func.returns.list
      m_arg = new ProxyType( ret.name.text )
      #m_arg.parse( arg.decl )
      @returns.push m_arg

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
  as_json: -> super( _type: 'statement', tree: @tree )
  constructor: (tree)->
    @tree = {}
    @processTree tree


  processTree: (tree, output={})->

    assert_token_group tree, 'statement'

    ## filter out the statements
    #if tree._group != 'statement'
      #throw new Error("expected statement, got #{tree._group}.#{tree._type}")

    _t = tree._type
    switch
      #when _t in ["EXPR"] then @tree = new Expression( tree.expr )
      when _t in ["EXPR"] then @tree = make_expression_tree(tree.expr)


make_expression_tree = (t)->
  assert_token_group t, 'expr'
  _type = t._type
  switch _type
    # Access chaining
    when "THIS" then new ThisExpression
    when "THIS_ACCESS" then new ThisAccessExpression( t.name )
    when "CALL" then new CallExpression( t.base, t.tail )
    when "CALL_MEMBER" then new CallMemberExpression( t.member, t.args, t.tail )
    when "PROPERTY_ACCESS" then new PropertyAccessExpression( t.name )
    when "CALL_CALLABLE" then new CallCallableExpression( t.args )
    # others
    when "MEMBER" then new MemberExpression( t.base, t.access_chain )
    when "VARIABLE" then new VariableExpression(  t.name.text )
    when "LITERAL" then new LiteralExpression( t.value.type, t.value.value )

    else
      switch
        when _type in ["ADD", "MUL", "SHITF", "RELATIONAL", "EQ", "ASSIGN"]
          new BinaryExpression( t.op, t.a, t.b )

        when _type in ["NEW"]
          new UnaryExpression( t.op, t.a )


        else
          winston.error "unknown token type: #{_type}", t
          throw new Error("Unknown expression token type: #{_type}")

class ThisExpression extends JsonSerializable
  as_json: -> super( _type: 'this' )
  constructor: ->

class ThisAccessExpression extends JsonSerializable
  as_json: -> super( _type: 'this_access', name: @name )
  constructor: ( name )->
    @name = name.text

class CallExpression extends JsonSerializable
  as_json: -> super( _type: 'call', base: @base, tail: @tail )
  constructor: (base, tail )->
    @base = make_expression_tree( base )
    @tail = (make_expression_tree( t ) for t in tail )

class CallMemberExpression extends JsonSerializable
  as_json: -> super( _type: 'call_member', member: @member, args: @args, tail:@tail )
  constructor: (member, args, tail )->
    @member = make_expression_tree( member )
    @args = (make_expression_tree( arg ) for arg in args)
    @tail = (make_expression_tree( arg ) for arg in tail)

class CallCallableExpression extends JsonSerializable
  as_json: -> super( _type: 'call_callable', args: @args )
  constructor: (args )->
    @args = (make_expression_tree( arg ) for arg in args)

class MemberExpression extends JsonSerializable
  as_json: -> super( _type: 'member_expression', base: @base, access_chain: @access_chain )
  constructor: (base, access_chain )->
    @base = make_expression_tree( base )
    @access_chain = (make_expression_tree( a ) for a in access_chain)
    #@access_chain = a


class PropertyAccessExpression extends JsonSerializable
  as_json: -> super( _type: 'property_access', name: @name )
  constructor: ( @name )->

class VariableExpression extends JsonSerializable
  as_json: -> super( _type: 'variable_expression', name: @name )
  constructor: (@name )->


class LiteralExpression extends JsonSerializable
  as_json: -> super( _type: 'literal_expression', type: @type, value: @value )
  constructor: ( @type, @value )->


class UnaryExpression extends JsonSerializable
  as_json: -> super( _type: 'unary_expression', op: @op, a: @a )
  constructor: (@op, a )->
    @a = make_expression_tree(a)


class BinaryExpression extends JsonSerializable
  as_json: -> super( _type: 'binary_expression', op: @op, a: @a, b: @b )
  constructor: (@op, a, b)->
    @a = make_expression_tree(a)
    @b = make_expression_tree(b)


class Expression extends JsonSerializable
  as_json: -> super( _type: 'expression', tree: @tree, op: @op, a: @a, b: @b )

  constructor: (tree)->
    @op = null
    @processTree tree

  processTree: (tree)->
    console.log "expr"
    console.log "--->", tree._group, tree._type
    if tree.op
      @op = tree.op
      console.log "op:", tree.op

    if tree.a
      console.log "A -> "
      @a = new Expression( tree.a )

    if tree.b
      console.log "B -> "
      @b = new Expression( tree.b )
    console.log "<---", tree._group, tree._type


type_base_map = CLASS: Class, STRUCT: Struct, ALIAS: Alias, CTYPE: CType

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
  type_instance.package = pkg
  type_instance

add_declarations_to_package = (pkg, declarations)->
  # Add the declarations
  for decl in declarations
    switch decl._type
      when 'TYPEDECL'
        type_name = decl.name.text
        type_instance = make_type_instance( pkg, type_name, decl )
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
