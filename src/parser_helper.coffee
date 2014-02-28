PEG = require 'pegjs'
fs = require 'fs'
_ = require 'underscore'


class ParserHelper
  constructor: (@parser)->

  parse_file: (filepath, callback)->
    parse_file @parser, filepath, callback

compile_parser = (data)->
  PEG.buildParser( data )

rebuild_parser = (grammar_path, callback)->
  fs.readFile grammar_path, encoding: 'UTF-8', (err, data)->
      throw err if err
      callback( compile_parser(data) )

parse_file = (parser, filepath, callback)->
  fs.readFile filepath, encoding: 'UTF-8', (err, data)->
    throw err if err
    res = parse_with_error_reports parser, filepath, data
    callback(res) if res

parse_with_error_reports = (parser, filename, data)->
  try
    parser.parse(data)
  catch err
    throw err unless err.name == "SyntaxError"
    report_error filename, err
    null


# fancy error reporting function
report_error = (filename, err)->
  console.error "#{filename}(#{err.line}:#{err.column}): #{err.message}"

_.extend exports,
  # Create a parser with a helper
  with_parser: (path, callback)->
    rebuild_parser path, (parser)->
      callback( new ParserHelper(parser) )




