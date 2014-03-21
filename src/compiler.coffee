_ = require 'underscore'
fs = require 'fs'
path = require 'path'
winston = require 'winston'
async = require 'async'

#parser_helper = require './parser_helper'
tree_parser = require './tree_parser/tree_parser'
#templates = require './templates'
builder = require './builder'


packaging = require './packaging'

resolver = require './resolver/resolver'

parser_map = require './parser_mapreducer/parser_map.coffee'

# Compile a list of package. For options, see bin/tcc-parser
compile_packages = (packageList, options, callback)->
  root = new packaging.Root( options.root )
  winston.info "Inside '#{path.normalize(root.dir)}'"

  parser_map.parsePackageList root, packageList, options, (err, res)->
    return callback(err, []) if err
    # separate the packages
    # write the parsed output if necessary
    #if options.saveTypeTree
      #package_dir.output_json "_.parsed.json", pack_data, (err, file_path, contents)->
      #return callback null, [file_path]

    #winston.info JSON.stringify( res, null, 2 )
    #if err
      #winston.error "error", err
      #winston.error err.stack
    callback( err, res )

  return
  #tree_parser.parse_packages root, package_list, options, (err, parsed_packages)->
    ## Handle errors
    #return callback(err, parsed_packages) if err
    ## Display some debug info
    #package_name_list = _.pluck(parsed_packages, "name")
    #winston.debug "Parsed #{parsed_packages.length} package(s): #{package_name_list.join(', ') }"

    ## drop out at this point if only the parse tree is necessary
    #return callback( null, package_name_list ) if options.saveParseTree
    #compile_parsed_package_fn = _.partial( compile_parsed_package, root, options )

    ## resolve and build each package paralell
    #async.map parsed_packages, compile_parsed_package_fn, (err, files)->
      #callback( err, files )

# resolve and build a single package
# TODO: handle inter-package dependencies (imports) here
compile_parsed_package = (root, options, pack, callback)->
  resolver.resolve_types pack, options, (err, resolved)->
    return callback(err, resolved) if err
    package_dir = root.get( pack.name )
    package_dir.output_json( "_.normalized", resolved ) if options.saveNormalizedForm

    builder.build_package_files resolved, package_dir, options, (err, files)->
      callback(err, files)



module.exports =
  compile_packages: compile_packages

