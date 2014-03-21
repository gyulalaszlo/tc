_             = require 'underscore'
async         = require 'async'

parser_helper = require '../parser/parser_helper'

GRAMMAR_FILE_ALT_PATH =  "#{__dirname}/../../grammar/tc2.pegjs"

# The first step in the compilation is parsing the package sources
parse_package_list = (root, package_list, options, callback)->

  async.auto {
    # Create the parser we are about to use
    parser: (callback)->
      parser_helper.with_parser GRAMMAR_FILE_ALT_PATH, options, (parser)->
        callback( null, parser )

    # Create a flat list of all the TC files to parse in the directory
    # that match the prerequisites in options
    file_list: (callback)->
      create_package_file_list root, package_list, options, (err, list)->
        callback( err, _.flatten( list ) )

    # For each TC file discovered, parse them with our parser in
    # parallel
    map_results: [ 'parser', 'file_list', (callback, results)->
      # parse the files in file_list with parser
      parse_fn = (file, callback)->
        results.parser.parse_file file.path, (res)->
          callback( null, res )

      # run the parsing paralel for the file list
      async.map results.file_list, parse_fn, (err, parsed)->
        callback( err, parsed )
    ]

    # After the parsing is complete for all files, we need to flatten the
    # emitted declarations from the different files into modules
    reduce_results: [ 'map_results', (callback, results)->
      packages = _.reduce( results.map_results, reduce_parse_results, {} )
      callback( null, packages )
    ]

    separate_definitions: [ 'reduce_results', (callback, results)->
      pack_data = null
      try
        pack_data = _.map results.reduce_results, separate_package_definitions
      catch err
        return callback(err, null)
      callback( null, pack_data )
    ]
  }, (err, results)->
      return callback( err, null ) if err
      callback( null, results.separate_definitions )





# Create a list of all the tc files in the given packages.
# callback: (err, [paths])
create_package_file_list = (root, package_list, options, callback)->
  # create the package dir objects
  package_dirs = for package_name in package_list
    root.getOrCreate package_name

  # get the file list of a single package
  map_fn = (dir, callback)->
    dir.with_tc_files (err, fileList)->
      callback( err, fileList  )

  # run all the packages in paralel
  async.map package_dirs, map_fn, (err, package_file_list)->
    callback( err, package_file_list )

# Copy all the properties of what to memo and concat any array
# properties
merge_with = (memo, what)->
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
        merge_with( existing, v )
      # otherwise just set the property
      else
        memo[k] = v
  # return just in case
  return memo

# Collect the definitions from the multiple emitted definitions
# into a single structured object grouped by package
reduce_parse_results = (memo, definitions )->

  # While the current implementation only emits definitions
  # from a single module in a pass, it may not always be the
  # case, so lets be on the safe side
  package_defs = _.groupBy( definitions, 'package' )
  # merge with the existing definitions
  merge_with( memo, package_defs )
  # remove the "package" property from the definitions
  for pack_name, package_data of memo
    for def in package_data
      delete def.package
  return memo


# Map function to split a packages definitions into the standard package 
# object categories:
# - types
# - method_sets
# - templates
separate_package_definitions = (pack)->
  field_map = { typedef: 'types', methodset: 'method_sets' }
  # group by _type and delete the field itself
  _.groupBy pack, (el)->
    ret = field_map[el._type]
    delete el._type
    ret


module.exports =
  parse_package_list: parse_package_list
