PEG = require 'pegjs'
fs = require 'fs'
path =require 'path'
_ = require 'underscore'
winston = require 'winston'


class ParserHelper
  constructor: (@parser)->

  parse_file: (filepath, callback)->
    parse_file @parser, filepath, callback

  parse_file_sync: (filepath, callback)->
    parse_file_sync @parser, filepath, callback


class GenericNode
  constructor: (attrs)->
    # copy the attributes
    _.extena @, @attrs

make_generic_node: (list, data)->
  param_names = list[1..]

# When customizing templateSettings, if you don’t want to define an
# interpolation, evaluation or escaping regex, we need one that is guaranteed not
# to match.
noMatch = /(.)^/
parser_compiler_options =
  return_expr: /->\{\{(.*?)\}\}/g
  inside: /^\s*([a-zA-Z][a-z\/\.A-Z_]*)\s+with\s+(.*?)\s*$/

  include_expr: /\{\{\s*include\s+([a-z_]+)\s*\}\}/


preprocess_parser_data = ( grammar_path, data, settings)->
  settings = _.defaults {}, settings, parser_compiler_options
  matcher = new RegExp( [
    (settings.return_expr || noMatch).source
    (settings.include_expr || noMatch).source
    #(settings.evaluate || noMatch).source
  ].join('|'), 'g');
  #console.log matcher

  # find the directory to look for partials in
  include_dir = path.dirname( grammar_path ) 
  # Compile the parser source
  data = data.replace matcher, (match, returner, includer,  offset)->

    if returner
      # split with the regex
      returner = returner.replace settings.inside, (match, key, params)->
        parts = ["_type: \"#{key}\""]
        for param in params.split /\s*,\s*/
          parts.push "#{param}: #{param}"
        parts.join(', ')
      return "{ return { #{returner}  }; }"

    if includer
      file_name = "_#{includer}.peg"
      file_path = path.join( include_dir, file_name )
      if !fs.existsSync( file_path )
        throw new Error("Cannot open included grammar: #{} (included from #{grammar_path}, at offset: #{offset}")

      contents = fs.readFileSync file_path, encoding: "UTF-8"
      return preprocess_parser_data( file_path, contents, settings )


  data



compile_parser = (grammar_path, data, settings)->
  data = preprocess_parser_data( grammar_path, data, settings )
  # build the pegjs parser from the compiled stuff
  try
    PEG.buildParser( data )
  catch err
    winston.error "Error while compiling PEG grammar"
    report_error( grammar_path, err )

    WINDOW_SIZE = 100
    start = Math.max 0, err.offset - WINDOW_SIZE
    end = Math.min data.length, err.offset + WINDOW_SIZE
    winston.error data[ start..(err.offset) ]
    winston.error data[ (err.offset)..end ]
    process.exit(-1)


rebuild_parser = (grammar_path, callback)->
  grammar_path = path.normalize( grammar_path  )
  fs.readFile grammar_path, encoding: 'UTF-8', (err, data)->
    throw err if err
    parser = compile_parser grammar_path, data
    winston.verbose "using grammar: #{grammar_path}"
    callback parser

# Internal helper function for parsing a file either sync or async
parse_file_internal = (parser, filepath, err, data, callback)->
  throw err if err
  res = parse_with_error_reports parser, filepath, data
  callback(res) if res


parse_file_sync = (parser, filepath, callback)->
  data = fs.readFileSync filepath, encoding: 'UTF-8'
  parse_file_internal( parser, filepath, null, data, callback)

parse_file = (parser, filepath, callback)->
  fs.readFile filepath, encoding: 'UTF-8', (err, data)->
    parse_file_internal( parser, filepath, err, data, callback)

parse_with_error_reports = (parser, filename, data)->
  try
    parser.parse(data)
  catch err
    throw err unless err.name == "SyntaxError"
    report_error filename, err
    process.exit(-1)


# fancy error reporting function
report_error = (filename, err)->
  winston.error "syntax_error", "#{filename}(#{err.line}:#{err.column}): #{err.message}", err

_.extend exports,
  # Create a parser with a helper
  with_parser: (path, callback)->
    rebuild_parser path, (parser)->
      callback( new ParserHelper(parser) )




