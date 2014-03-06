_ = require 'underscore'
fs = require 'fs'
path = require 'path'
winston = require 'winston'
async = require 'async'

parser_helper = require './parser_helper'
templates = require './templates'
builder = require './builder'

tc_packages = require './metadata'
util = require './util'


class ScopeList
  constructor: ->
    @levels = [{}]
    @path = []

  add_level: (name)->
    @path.push name
    @levels.push {}

  remove_level: ->
    if @levels.length < 2
      throw new Error("Cannot remove any more levels from the ScopeList")
    @path.pop()
    @levels.pop()


  with_level: (name, callback)->
    @add_level(name)
    callback()
    @remove_level()

  current: -> @levels[ @levels.length - 1 ]

  get: (key)->
    i = @levels.length
    while i > 0
      i--
      return @levels[i][key] if @levels[i][key]
    null


class TcRoot
  constructor: (@dir)->
    throw new Error("Package root directory not set.") unless @dir
    @packages = {}
    @output_dir = path.join( @dir, ".tc" )


  add: (package_location)->
    @packages[package_location.name] = package_location
    package_location.root = @
  get: (name)-> @packages[name]


class TcPackageLocation
  constructor: (@name)->


  dir: -> @_dir ||= path.join( @root.dir, @name )
  output_dir: -> @_output_dir ||= path.join( @root.output_dir, @name )

  # Save something to the output directory
  output_file: (filename, contents)->
    file_path = path.join( @output_dir(), filename )
    util.write_file file_path, contents

  # Save something to the output dir as JSON
  output_json: (filename, obj)->
    @output_file( filename, JSON.stringify(obj, null, 2) )

  # Does the package directory exist?
  must_exist: (callback)->
    package_path = @dir()
    fs.exists package_path, (err, res)->
      callback(err, res)


  with_tc_files: (opts, callback)->
    callback = callback ? opts
    _.defaults opts, package_files: true, test_files: false
    package_path = @dir()
    package_dir = @
    @must_exist (exists)->
      return callback([]) unless exists
      # now the directory exists
      fs.readdir package_path, (err, files)->
        # the current map function to filter the file list
        filename_eraser = (fn)-> if util.is_tc_file(fn) then { path: path.join(package_path, fn), file: fn, dir: package_dir } else null
        # map to all file names
        all_files = _.chain( files ).map( filename_eraser ).without( null ).value()
        callback(all_files)





# Compile a list of package. For options, see bin/tcc-parser
compile_packages = (package_list, options)->
  root = new TcRoot( options.root )
  parse_packages root, package_list, options, (parsed_packages)->
    package_name_list = _.pluck(parsed_packages, "name")
    winston.debug "Parsed #{parsed_packages.length} package(s): #{package_name_list.join(', ') }"

    # resolve the types in this package
    for pack in parsed_packages
      resolved = resolve_types pack, options
      package_dir = root.get( pack.name )
      #package_path = get_package_path( pack.name, options )
      package_dir.output_json( "_.normalized", resolved ) if options.saveNormalizedForm
      #save_normalized_lists( resolved, package_path, options)

      builder.build_package_files( resolved, package_dir, options )



# The first step in the compilation is parsing the package sources
parse_packages = (root, package_list, options, callback)->
  # load the parser
  parser_helper.with_parser "#{__dirname}/../grammar/tc.peg", (parser)->
    parsed_packages = []
    # packages can be parsed paralell
    parse_package_partial = _.partial( parse_package, parser, root, options )
    async.map package_list, parse_package_partial, (err, results)->
      callback(results)

# Parse a single package
parse_package = (parser, root, options, package_name, callback)->
  # create the package location handler
  package_dir = new TcPackageLocation( package_name )
  root.add package_dir
  #
  winston.info "Starting to parse package '#{package_name}'"
  # get the package path
  # wait for the package file list
  package_dir.with_tc_files (file_list)->
    parse_package_file_partial = _.partial( parse_package_file, parser, options )
    async.map file_list, parse_package_file_partial, (err, package_files)->
      # Make a package from the units
      pack = tc_packages.from_units package_files
      pack_data = pack.as_json()
      # store it
      #parsed_packages.push pack_data
      # and display some misc info
      winston.info "package '#{package_name}' parsed."
      package_dir.output_json( "_.typetree", pack_data ) if options.saveTypeTree
      callback( null, pack_data )

parse_package_file = (parser, options, file, callback)->
  parse_fn = (callback)->
    parser.parse_file file.path, (res)->
      file.dir.output_json( "#{path.basename(file.path)}.parsed", res ) if options.saveParseTree
      winston.debug "parsed source: #{file.file} -> '#{file.path}'"
      callback( null, res )

  log_wrapper = (func, callback)->
    winston.info "source: #{file.file}"
    func (err, res)->
      winston.info "parsed source: #{file.file} -> '#{file.path}'"
      callback( err, res )

  _.wrap( parse_fn, log_wrapper )(callback)



# resolve any types in the package
resolve_types = (pack, options)->
  winston.debug "starting to resolve types of '#{pack.name}'"
  # create the normalized package data
  normalized_package = {name: pack.name, typelist: [], method_lists: [], expressions: []}
  # and cache it to local vars
  {typelist:typelist, method_lists:method_lists, expressions: expressions} = normalized_package

  scoped = new ScopeList
  scoped.with_level pack.name, ->
    resolve_typelist(pack, typelist, scoped)
    mlr = new MethodlistResolver( pack, normalized_package, scoped)
    method_lists = mlr.method_lists

  normalized_package

# resolve the root typelists entries in the package
resolve_typelist = (pack, typelist, scoped)->
  # forward-declare all local types so we can resolve them later
  for name, t of pack.types
    typelist.push { _type: "proxy", name: name, public: util.is_published(name) }


  # go through each type and fill in the missing declrations
  # since the proxies go by name, we can replace by name
  for name, t of pack.types
    scoped.with_level name, ->
      switch
        # C types are already ok, no need to resolve
        when t._type == "ctype"
          replace_in_typelist typelist, name, { _type: "ctype", name: name, raw: t.c_name }

        # An alias should point to a resolved orignal
        when t._type == "alias"
          original_type_name = t.original
          resolved = resolve_type(t.original.name, scoped, typelist)
          replace_in_typelist typelist, name, { _type: "alias", name: name, original: resolved }

        # Classes and structs need their fields resolved
        when t._type in ['class', 'struct']
          fields = []
          for field in t.fields
            fields.push { name: field.name, type: resolve_type( field.type.name, scoped, typelist ) }
          replace_in_typelist typelist, name, { _type: t._type, name: name, fields: fields }

class TypelistHandler
  constructor: ->
    @typelist = []


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
  for t,i in typelist
    # if the type matches, return the index in the typelist
    return i if typename == t.name
  # If the type cannot be resolved, we have a problem
  throw new Error("Cannot resolve type name: '#{typename}' inside '#{current_scope.path.join('/')}'")





class MethodlistResolver
  constructor: (@pack, @normalized_package, @scoped)->
    # cache some things for legacy code
    @typelist = @normalized_package.typelist
    @method_lists = @normalized_package.method_lists
    @expressions = @normalized_package.expressions
    # create something to store the expressions that get generated
    @expressions = new ExpressionTreeList @typelist, @method_lists, @expressions

    for method_list in pack.method_lists
      target_name = method_list.type.name
      access = method_list.access
      target = @resolve_type target_name

      methods = []
      for method in method_list.methods
        methods.push @single_definition(method, target)

      @method_lists.push { _type: "method_list", target: target, methods: methods, access: access }


  single_definition: (method, target)->
    resolver = new SingleDefinitionResolver( @normalized_package, target )
    resolver.resolve( method )

  resolve_type: (name)->
    resolve_type( name, @scoped, @typelist )


class SingleDefinitionResolver
  # the package and the target (receiver) of this method
  constructor: (@pkg, @target)->
    # cache some things for legacy code
    @typelist = @pkg.typelist
    @method_lists = @pkg.method_lists
    @expressions = @pkg.expressions

    # the expression tree resolver
    @expression_resolver = new ExpressionTreeResolver(@typelist, @method_list, @target)

    @resolvers =
      cassign: new CAssignStatementResolver
    resolver.parent = @ for k,resolver of @resolvers

  resolve: (method)->
    args = ({ name: a.name, type: @resolve_type(a.type.name) } for a in method.args)
    returns = ({ type: @resolve_type(r.name) } for r in method.returns)
    method_def = { name: method.name, args: args, returns: returns }
    method_def.body = @resolve_body method_def, method.body
    method_def

  resolve_body: (method_def, statement_list)->
    for s in statement_list
      switch s._type
        #when "cassign" then new CAssignStatementResolver().resolve( s )
        when "return" then { _type: "return", expr: @expression_resolver.resolve_tree(s.tree) }
        when "expression" then { _type: "expression", expr: @expression_resolver.resolve_tree(s.tree) }

        else
          resolver = @resolvers[s._type]
          resolver.target = @target
          resolver.resolve( s )

  resolve_type: (name)->
    resolve_type( name, @scoped, @typelist )


# Create and Assign statements need their type deduced
class CAssignStatementResolver
  resolve: (t)->
    # get the initializer expression
    initializer_expression = @parent.expression_resolver.resolve_tree(t.tree) 
    throw new Error("Cannot resolve right hand side of Create and Assign statement. - #{JSON.stringify(t)}") unless initializer_expression
    console.log initializer_expression
    # this tells us our type
    type = initializer_expression.type
    throw new Error("Cannot resolve type for left hand side of Create and Assign statement. - #{JSON.stringify(initializer_expression)}") unless type
    { _type: "cassign", name: t.name, expr: initializer_expression, type: type  }

# Helper object to construct and resolve expression trees and put them in a linear
# array for easy referencing
class ExpressionTreeList
  constructor: (@typelist, @method_lists, @expressions)->

  add: (resolved_type)->
    idx = @expressions.length
    resolved_type = @resolver.resolve_tree tree
    @expressions.push resolved_type
    #idx
    resolved_type


class ExpressionTreeResolver
  constructor: (@typelist, @method_list, @target)->
    @resolvers =
      this: new ThisResolver
      binary_expression: new BinaryExpressionResolver
      literal_expression: new LiteralExpressionResolver
      variable_expression: new VariableExpressionResolver
      member_expression: new MemberExpressionResolver
      call_member: new MemberCallExpressionResolver
    # assign the parents for usage
    resolver.parent = @ for k,resolver of @resolvers

  resolve_tree: (t)->
    resolver = @resolvers[t._type]
    throw new Error("Unknown expression type: #{ t._type }") unless resolver
    resolver.resolve(t)

class BinaryExpressionResolver
  resolve: (t)->
    # resolve both operands
    a = @parent.resolve_tree(t.a)
    b = @parent.resolve_tree(t.b)
    # check the op
    op = t.op
    switch
      when op in ["=", "+=", "-="]
        return { _type: "assignment_expr", op: op, a: a, b: b }
      when op in ["+", "-", "/", "*"]
        return { _type: "binary_expr", op: op, a: a, b: b }
      else
        throw new Error("Unknown BINARY operator: #{ op }")

node_factories =
  # common helper for ThisResolver and ThisAccessResolver
  this: ( type_id )-> { _type: "this", type: type_id }

  # common helper for outputting a member access node
  member_access: (base, access_chain, type_id )->
    { _type: "member", base: base, access_chain: access_chain, type: type_id  }

  property_access: (name)-> { _type: "property", name: name  }

class ThisResolver
  resolve: (t)->
    node_factories.this( @parent.target )


class LiteralExpressionResolver
  resolve: (t)->
    #if t.
    return { _type: "literal", value: t.value, type: t.type  }

class MemberExpressionResolver
  resolve: (t)->
    base = @parent.resolve_tree(t.base)
    access_chain = []
    # When we start with a "this" access, add the @access to
    # the access chain.
    if base._type == "member"
      # use the original base
      base = base.base
      # and copy over the old access chain
      access_chain.concat base.access_chain

    current_type_id = base.type
    current_type = @parent.typelist[current_type_id]

    for chain_el in t.access_chain
      switch chain_el._type
        when "property_access"
          prop_name = chain_el.name
          result = node_factories.property_access( chain_el.name )
          # check if the type has any such properties
          field = _.findWhere( current_type.fields, name: prop_name )
          switch
            when field
              result.type = current_type_id = field.type
            else
              throw new Error("Method lookup not implemented")
              method_lists = _.where( @parent.method_lists, target: current_type_id )
              matching_methods
              method = _findWhere( current_type.fields, name: prop_name )

          current_type = @parent.typelist[current_type_id]
          access_chain.push( result )


    node_factories.member_access( base, access_chain, current_type_id )





class VariableExpressionResolver
  resolve: (t)->
    return { _type: "variable", name: t.name  }

class MemberCallExpressionResolver
  resolve: (t)->
    return { _type: "member_call", member: t.member ,args: t.args, tail: t.tail  }


module.exports =
  compile_packages: compile_packages

