_             = require 'underscore'
async         = require 'async'

parserHelper = require '../parser/parser_helper'

GRAMMAR_FILE_ALT_PATH =  "#{__dirname}/../../grammar/tc2.pegjs"

# The first step in the compilation is parsing the package sources
# parsePackageList parses all the passed packages, and builds a
# tree for each package:
#
# - types: the top-level types declared in the package
# - method_sets: the method sets declared in the package
#
# The types and any method calls in the tree are still in their token
# form, awaiting for resolution.
parsePackageList = (root, packageList, options, callback)->

  async.auto {
    # Create the parser we are about to use
    parser: (callback)->
      parserHelper.with_parser GRAMMAR_FILE_ALT_PATH, options, (parser)->
        callback( null, parser )

    # Create a flat list of all the TC files to parse in the directory
    # that match the prerequisites in options
    fileList: (callback)->
      createPackageFileList root, packageList, options, (err, list)->
        callback( err, _.flatten( list ) )

    # For each TC file discovered, parse them with our parser in
    # parallel
    mapResults: [ 'parser', 'fileList', (callback, results)->
      # parse the files in file_list with parser
      parseFn = (file, callback)->
        results.parser.parse_file file.path, (res)->
          callback( null, res )

      # run the parsing paralel for the file list
      async.map results.fileList, parseFn, (err, parsed)->
        callback( err, parsed )
    ]

    # After the parsing is complete for all files, we need to flatten the
    # emitted declarations from the different files into modules
    reduceResults: [ 'mapResults', (callback, results)->
      # get a list of packages
      packages = _.reduce( results.mapResults, reduceParseResults, {} )
      # add the package name as a property of the package data
      #pack.name = k for k, pack of packages
      callback( null, packages )
    ]

    # separate the definitions in each package into their respective types
    # (types, method_sets, templates)
    separateDefinitions: [ 'reduceResults', (callback, results)->
      packages = _.pairs results.reduceResults
      console.log "packages: ", packages
      packData = _.map packages, separatePackageDefinitions
      callback( null, packData )
    ]
  }, (err, results)->
      return callback( err, null ) if err
      callback( null, results.separateDefinitions )





# Create a list of all the tc files in the given packages.
# callback: (err, [paths])
createPackageFileList = (root, packageList, options, callback)->
  # create the package dir objects
  packageDirs = for packageName in packageList
    root.getOrCreate packageName

  # get the file list of a single package
  mapFn = (dir, callback)->
    dir.with_tc_files (err, fileList)->
      callback( err, fileList  )

  # run all the packages in paralel
  async.map packageDirs, mapFn, (err, packageFileList)->
    callback( err, packageFileList )

# Copy all the properties of what to memo and concat any array
# properties
mergeWith = (memo, what)->
  for k,v of what
    existing = memo[k]
    switch

      # if the existing property is an array, merge our array
      # with it
      when _.isArray existing
        # check if we can merge
        unless _.isArray( v )
          throw new Error("Tried to merge an array property and a non-array property: #{ JSON.stringify( key: k, value: v, existing: existing ) }")
        # merge
        memo[k] = existing.concat v

      when _.isObject existing
        mergeWith( existing, v )
      # otherwise just set the property
      else
        memo[k] = v
  # return just in case
  return memo

# Collect the definitions from the multiple emitted definitions
# into a single structured object grouped by package
reduceParseResults = (memo, definitions )->
  # While the current implementation only emits definitions
  # from a single module in a pass, it may not always be the
  # case, so lets be on the safe side
  packageDefs = _.groupBy( definitions, 'package' )
  # merge with the existing definitions
  mergeWith( memo, packageDefs )
  # remove the "package" property from the definitions
  for packName, packageData of memo
    for def in packageData
      delete def.package
  return memo


# Map function to split a packages definitions into the standard package
# object categories:
# - types
# - method_sets
# - templates
separatePackageDefinitions = (packageArr)->
  # decompose the name-package pair
  [packageName, pack] = packageArr
  # the mapping of definition types to list
  fieldMap = { typedef: 'types', methodset: 'method_sets' }
  # group by _type and delete the field itself
  ret = _.groupBy pack, (el)->
    ret = fieldMap[el._type]
    delete el._type
    ret
  # set the package name
  ret.name = packageName
  ret


module.exports =
  parsePackageList: parsePackageList
