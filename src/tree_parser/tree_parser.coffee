_             = require 'underscore'
winston       = require 'winston'
async         = require 'async'
path          = require 'path'

parser_helper = require '../parser/parser_helper'
tc_packages   = require '../metadata'

GRAMMAR_FILE_PATH =  "#{__dirname}/../../grammar/tc.peg"

# The first step in the compilation is parsing the package sources
parse_packages = (root, package_list, options, callback)->
  # load the parser
  parser_helper.with_parser GRAMMAR_FILE_PATH, (parser)->
    parsed_packages = []
    # packages can be parsed paralell
    parse_package_partial = _.partial( parse_package, parser, root, options )
    async.map package_list, parse_package_partial, (err, results)->
      callback(results)

# Parse a single package
parse_package = (parser, root, options, package_name, callback)->
  # create the package location handler
  package_dir = root.getOrCreate package_name
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
      # display some misc info
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


_.extend exports,
   parse_packages: parse_packages
