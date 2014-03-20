PEG = require 'pegjs'
fs = require 'fs'
path =require 'path'
_ = require 'underscore'

os = require 'os'

winston = require 'winston'
Bench = require '../bench'


GrammarPreprocessor = require './grammar_preprocessor'
ParserPrecompiler = require './parser_precompiler'

# The type exported by make_parser
class ParserHelper
  constructor: (@parser)->

  parse_file: (filepath, callback)->
    parse_file @parser, filepath, callback

  parse_file_sync: (filepath, callback)->
    parse_file_sync @parser, filepath, callback

PEG_OPTIONS = {}








compile_parser = (grammar_path, data, settings)->
  #parser_compiler = new ParserPrecompiler( settings )
  preprocessor = new GrammarPreprocessor( settings )
  data = preprocessor.processGrammar grammar_path, data
  #data = preprocess_parser_data( grammar_path, data, settings )
  # build the pegjs parser from the compiled stuff
  try
    #parser_compiler.compile grammar_path
    PEG.buildParser( data )
  catch err
    winston.error "Error while compiling PEG grammar"
    report_error( grammar_path, err )

    return
    # Parser building error reporter...
    WINDOW_SIZE = 100
    start = Math.max 0, err.offset - WINDOW_SIZE
    end = Math.min data.length, err.offset + WINDOW_SIZE
    winston.error data[ start..(err.offset) ]
    winston.error data[ (err.offset)..end ]
    process.exit(-1)


rebuild_parser = (grammar_path, callback)->
  compiler = new ParserPrecompiler( os.tmpdir() )
  grammar_path = path.normalize( grammar_path  )

  winston.verbose "compiling grammar: #{grammar_path}"
  compiler.compile grammar_path, (err, parser)->
    #callback(err, parser)
    if err
      report_error( grammar_path, err )
      return callback( err, null )
    #return report_error( grammar_path, err ) if err
    #console.log parser
    winston.verbose "using grammar: #{grammar_path}"
    callback null, parser

  return
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
  with_parser: (path, options, callback)->
    if options.rebuildGrammar
      bench = new Bench("Rebuilt PEGjs parser", true)
      rebuild_parser path, (err, parser)->
        throw new Error("Cannot build parser") if err
        bench.stop()
        callback( new ParserHelper(parser) )
    else
      parser = require '../../lib/tc.peg'
      callback( new ParserHelper(parser) )




