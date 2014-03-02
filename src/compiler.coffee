_ = require 'underscore'
fs = require 'fs'
path = require 'path'

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
    callback( file )

say_status = (what, text)->
  console.log "#{what} : #{text}"

write_file = (file, contents)->
  fs.writeFile file, contents, (err)->
    throw err if err
    say_status "written", file

# Write the parsed tree to the corresponding file
save_parse_tree = (tree, file, package_path, options)->
  file_path = path.join( package_path, ".#{ path.basename(file)}.parsed" )
  write_file file_path, JSON.stringify(tree, null, 2)

# Write the parsed tree to the corresponding file
save_type_tree = (tree, file, package_path, options)->
  file_path = path.join( package_path, ".#{ path.basename(file)}.typetree" )
  write_file file_path, JSON.stringify(tree, null, 2)

compile_packages = (package_list, options)->
  # find the root directory
  root_dir = get_root_dir options
  # load the parser
  parser_helper.with_parser "#{__dirname}/../grammar/tc.peg", (parser)->
    # go through each given package
    for package_name in package_list
      say_status "package", package_name
      # get the package path
      package_path = get_package_path( package_name, options )
      package_files = []
      each_package_file package_path, (f)->
        # try to parse the file
        parser.parse_file_sync "examples/test.tc", (res)->
          save_parse_tree( res, f, package_path, options ) if options.saveParseTree
          package_files.push res
          say_status "parsed", f

      pack = tc_packages.from_units package_files
      say_status "typetree", package_name
      pack_data = pack.as_json()
      save_type_tree(pack.as_json(), package_name, package_path, options) if options.saveTypeTree




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

