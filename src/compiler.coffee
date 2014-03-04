_ = require 'underscore'
fs = require 'fs'
path = require 'path'
winston = require 'winston'

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


  # Run the callback for each .tc file in the 
  # package path that may be a valid TC file.
  each_tc_file: (callback)->
    package_path = @dir()
    # if the package dir is invalid, signal it
    unless fs.existsSync(package_path)
      throw new Error("The package #{@name} cannot be found at #{package_path}.")
    # go through the files
    files = fs.readdirSync package_path
    for file in files
      continue unless util.is_tc_file(file)
      callback( path.join(package_path, file), file )



#get_root_dir = (options)->
  #throw new Error("Package root directory not set.") unless options.root
  #path.normalize( options.root )

#get_package_path = (package_name, options)->
  ## find the root directory
  #root_dir = get_root_dir options
  ## find the package path
  #package_path = path.join root_dir, package_name
  ## check if the package path is a valid one
  #return package_path if fs.existsSync( package_path )
  ## an invalid package was given
  #throw new Error("The package #{package_name} cannot be found at #{package_path}.")

## Run the callback for each .tc file in the package path that may be a valid TC file.
#each_package_file = (package_path, callback)->
  #files = fs.readdirSync package_path
  #for file in files
    #continue unless util.is_tc_file(file)
    #callback( path.join(package_path, file), file )



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
    # go through each given package
    for package_name in package_list
      # create the package location handler
      package_dir = new TcPackageLocation( package_name )
      root.add package_dir
      #
      winston.debug "starting to parse package '#{package_name}'"
      # get the package path
      #package_path = get_package_path( package_name, options )
      package_files = []
      package_dir.each_tc_file (f, filename)->
        # try to parse the file
        parser.parse_file_sync f, (res)->
          package_dir.output_json( "#{path.basename(f)}.parsed", res ) if options.saveParseTree
          #save_parse_tree( res, f, package_path, options ) if options.saveParseTree
          package_files.push res
          winston.debug "parsed source: #{filename} -> '#{f}'"
          #say.status_v "source", "#{filename} (#{f})"

      # Make a package from the units
      pack = tc_packages.from_units package_files
      pack_data = pack.as_json()
      # store it
      parsed_packages.push pack_data
      # and display some misc info
      winston.debug "package '#{package_name}' parsed."
      #save_type_tree(pack.as_json(), package_path, options) if options.saveTypeTree
      package_dir.output_json( "_.typetree", pack_data ) if options.saveTypeTree

    # callback with the list of parsed packages
    callback(parsed_packages)


# resolve any types in the package
resolve_types = (pack, options)->
  winston.debug "starting to resolve types of '#{pack.name}'"
  typelist = []
  method_lists = []
  scoped = new ScopeList
  scoped.with_level pack.name, ->
    resolve_typelist(pack, typelist, scoped)
    mlr = new MethodlistResolver( pack, typelist, method_lists, scoped)
    method_lists = mlr.method_lists
    #method_lists = resolve_function_arguments( pack, typelist, scoped)

  {name: pack.name, typelist: typelist, method_lists: method_lists}

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
        when t._type == "alias"
          original_type_name = t.original
          resolved = resolve_type(t.original.name, scoped, typelist)
          replace_in_typelist typelist, name, { _type: "alias", name: name, original: resolved }

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
  constructor: (@pack, @typelist, @method_lists, @scoped)->
    for method_list in pack.method_lists
      target_name = method_list.type.name
      access = method_list.access
      target = @resolve target_name

      methods = []
      for method in method_list.methods
        methods.push @single_definition(method)

      @method_lists.push { _type: "method_list", target: target, methods: methods, access: access }


  single_definition: (method)->
    args = ({ name: a.name, type: @resolve(a.type.name) } for a in method.args)
    returns = ({ type: @resolve(r.name) } for r in method.returns)
    { name: method.name, args: args, returns: returns }

  resolve: (name)->
    resolve_type( name, @scoped, @typelist )

module.exports =
  compile_packages: compile_packages

