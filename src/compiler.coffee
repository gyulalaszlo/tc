_ = require 'underscore'
fs = require 'fs'
path = require 'path'
winston = require 'winston'
async = require 'async'

#parser_helper = require './parser_helper'
tree_parser = require './tree_parser/tree_parser'
#templates = require './templates'
builder = require './builder/builder'


packaging = require './packaging'

resolver = require './resolver/resolver'

parser_map = require './parser_mapreducer/parser_map'
resolver = require './parser_mapreducer/resolver'

withRoot = (options, callback)->
  root = new packaging.Root( options.root )
  winston.info "Inside '#{path.normalize(root.dir)}'"
  callback(null,root)

# Compile a list of package. For options, see bin/tcc-parser
compile_packages = (packageList, options, callback)->
  withRoot options, (err, root)->
    parser_map.parsePackageList root, packageList, options, (err, packages)->
      return callback(err, []) if err
      # Stop going forward if the type tree is requested
      if options.saveTypeTree
        return saveTypeTree root, packages, (err, files)->
          callback( err, files )

      # time to resolve the packages
      resolver.resolvePackageList packages, (err, resolved_packages)->
        return callback(err, []) if err
        if options.saveNormalizedForm
          return saveNormalizedForm root, resolved_packages, (err, files)->
            callback( err, files )

        # We are finished
        callback( err, [] )

buildPackages = (packageList, options, callback)->
  withRoot options, (err, root)->
    builder.buildOutput root, packageList, options, (err, files)->
      callback(err, files)

# resolve and build a single package
# TODO: handle inter-package dependencies (imports) here
#compile_parsed_package = (root, options, pack, callback)->
  #resolver.resolve_types pack, options, (err, resolved)->
    #return callback(err, resolved) if err
    #package_dir = root.get( pack.name )
    #package_dir.output_json( "_.normalized", resolved ) if options.saveNormalizedForm

    #builder.build_package_files resolved, package_dir, options, (err, files)->
      #callback(err, files)


# Write out the type trees for all the packages
saveTypeTree = ( root, packages, callback )->
  # write out a packages typetree
  writePackage = (pack, callback)->
    packageDir = root.getOrCreate pack.name
    packageDir.output_json "_.parsed.json", pack, (err, filePath, contents)->
      callback( err, filePath )

  async.map packages, writePackage, (err, filePaths)->
    callback( err, filePaths )



# Write out the type trees for all the packages
saveNormalizedForm = ( root, resolved_packages, callback )->
  # write out a packages typetree
  writePackage = (pack, callback)->
    #console.log pack
    packageDir = root.getOrCreate pack.name
    packageDir.outputNormalizedFile pack, (err, filePath, contents)->
      callback( err, filePath )

  async.map resolved_packages, writePackage, (err, filePaths)->
    callback( err, filePaths )

module.exports =
  compile_packages: compile_packages
  buildPackages: buildPackages

