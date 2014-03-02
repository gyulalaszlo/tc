_ = require 'underscore'
fs = require 'fs'
path = require 'path'

say = require './say'
parser_helper = require './parser_helper'
templates = require './templates'

tc_packages = require './metadata'



get_root_dir = (options)->
  throw new Error("Package root directory not set.") unless options.root
  path.normalize( options.root )

get_package_path = (package_name, options)->
  # find the root directory
  root_dir = get_root_dir options
  # find the package path
  package_path = path.join root_dir, package_name
  # check if the package path is a valid one
  return package_path if fs.existsSync( package_path )
  # an invalid package was given
  throw new Error("The package #{package_name} cannot be found at #{package_path}.")

# Check if a file is a tc file
is_tc_file = (filename)->
  path.extname(filename) == '.tc'

# Run the callback for each .tc file in the package path that may be a valid TC file.
each_package_file = (package_path, callback)->
  files = fs.readdirSync package_path
  for file in files
    continue unless is_tc_file(file)
    callback( path.join(package_path, file), file )

write_file = (file, contents)->
  fs.writeFile file, contents, (err)->
    throw err if err
    say.status "written", file

# Write the parsed tree to the corresponding file
save_parse_tree = (tree, file, package_path, options)->
  file_path = path.join( package_path, ".#{ path.basename(file)}.parsed" )
  write_file file_path, JSON.stringify(tree, null, 2)

# Write the parsed tree to the corresponding file
save_type_tree = (tree, package_path, options)->
  file_path = path.join( package_path, ".package.typetree" )
  write_file file_path, JSON.stringify(tree, null, 2)


# Compile a list of package. For options, see bin/tcc-parser
compile_packages = (package_list, options)->
  parse_packages package_list, options, (parsed_packages)->
    package_name_list = _.pluck(parsed_packages, "name")
    say.status "parsing_done", "#{parsed_packages.length} package(s): #{package_name_list.join(', ') }"

    # resolve the types in this package
    for pack in parsed_packages
      resolve_types pack

# The first step in the compilation is parsing the package sources
parse_packages = (package_list, options, callback)->
  say.set_options options
  # find the root directory
  root_dir = get_root_dir options
  # load the parser
  parser_helper.with_parser "#{__dirname}/../grammar/tc.peg", (parser)->
    parsed_packages = []
    # go through each given package
    for package_name in package_list
      say.status_v "package", package_name
      # get the package path
      package_path = get_package_path( package_name, options )
      package_files = []
      each_package_file package_path, (f, filename)->
        # try to parse the file
        parser.parse_file_sync f, (res)->
          save_parse_tree( res, f, package_path, options ) if options.saveParseTree
          package_files.push res
          say.status_v "source", "#{filename} (#{f})"

      # Make a package from the units
      pack = tc_packages.from_units package_files
      pack_data = pack.as_json()
      # store it
      parsed_packages.push pack_data
      # and display some misc info
      say.status_v "package_parsed", package_name
      save_type_tree(pack.as_json(), package_path, options) if options.saveTypeTree

    # callback with the list of parsed packages
    callback(parsed_packages)


class ScopeList
  constructor: ->
    @levels = [{}]

  add_level: -> @levels.push {}
  remove_level: ->
    if @levels.length < 2
      throw new Error("Cannot remove any more levels from the ScopeList")
    @levels.pop

  current: -> @levels[ @levels.length - 1 ]

  get: (key)->
    i = @levels.length
    while i > 0
      i--
      return @levels[i][key] if @levels[i][key]
    null


add_package_type_to_scope = (pack, scoped)->
  c = scoped.current()
  for k,t of pack.types
    c[k] = t


resolve_types = (pack)->
  say.status_v "resolving types", pack.name
  scoped = new ScopeList
  typelist = []
  # add any defined types to the scoped stuff
  add_package_type_to_scope pack, scoped
  console.log scoped
  # go through each type
  for name, t of pack.types
    say.status_v "type", "#{name}"
    switch t._type
      # C types are already ok, no need to resolve
      when "ctype"
        typelist.push { _type: "ctype", name: name, raw: t.c_name }
      when "alias"
        original_type_name = t.original
        resolved = resolve_type(t.original.name, scoped, typelist)
        typelist.push { _type: "alias", name: name, original: resolved }

      when 'class'
        fields = []
        for field in t.fields
          fields.push { name: field.name, type: resolve_type( field.type.name, scoped, typelist ) }

        typelist.push { _type: "class", name: name, fields: fields }

  console.log JSON.stringify(typelist, null, 2)
  typelist

resolve_type = (typename, current_scope, typelist)->
  for t,i in typelist
    console.log i, typename, t
    # if the type matches, return the index in the typelist
    return i if typename == t.name
  throw new Error("Cannot resolve type name: #{typename}")
  return null

  return if node._resolved
  name = node.name
  found_type = current_scope.get( name )
  # give up on errors
  unless found_type
    throw new Error("Cannot resolve type: #{name}.")
  # if the type is found
  console.log found_type


build_class_files = (filename, units)->
  meta = {}
  each_matching_declaration units, "typedecl", (decl)->
    if decl.as.has_tag 'class'
      key = decl.name.text
      meta[key] = { type: decl }

  each_matching_declaration units, "method_set", (decl)->
    key = decl.name.toString()
    meta[key].methods ||= []
    meta[key].methods.push decl

  for k, v of meta
    class_tpl = require './templates/class'
    res = templates.run_c_tpl class_tpl, meta[k]
    #console.log res.toString()
    console.log res._tokens.toString()

each_matching_declaration = (units, tag, callback)->
  for unit in units
    for decl in unit.contents.declarations
      if decl.has_tag tag
        callback(decl)

module.exports =
  compile_packages: compile_packages

