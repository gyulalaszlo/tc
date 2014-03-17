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

packaging = require './packaging'

MethodListResolver = require './resolver/method_list_resolver'

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


# Compile a list of package. For options, see bin/tcc-parser
compile_packages = (package_list, options)->
  root = new packaging.Root( options.root )
  winston.info "Inside '#{path.normalize(root.dir)}'"
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
  #package_dir = new packaging.PackageDir( package_name )
  package_dir = root.getOrCreate package_name
  #
  winston.info "Starting to parse package '#{package_name}'"
  # get the package path
  # wait for the package file list
  package_dir.with_tc_files (file_list)->
    parse_package_file_partial = _.partial( parse_package_file, parser, options )
    async.map file_list, parse_package_file_partial, (err, package_files)->
      throw err if err
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
    mlr = new MethodListResolver( pack, normalized_package, scoped)
    method_lists.push mlr.method_lists...

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
          replace_in_typelist typelist, name, { _type: "ctype", name: name, raw: t.c_name, docs: t.docs }

        # An alias should point to a resolved orignal
        when t._type == "alias"
          original_type_name = t.original
          resolved = resolve_type(t.original.name, scoped, typelist)
          replace_in_typelist typelist, name, { _type: "alias", name: name, original: resolved, docs: t.docs }

        # Classes and structs need their fields resolved
        when t._type in ['class', 'struct']
          fields = []
          for field in t.fields
            fields.push { name: field.name, type: resolve_type( field.type, scoped, typelist ), docs: field.docs }
          replace_in_typelist typelist, name, { _type: t._type, name: name, fields: fields, docs: t.docs }


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
  compile_packages: compile_packages

