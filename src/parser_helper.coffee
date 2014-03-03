PEG = require 'pegjs'
fs = require 'fs'
_ = require 'underscore'

say = require './say'

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
  inside: /^\s*([A-Z_]+)\s+with\s+(.*?)\s*$/
  #inside: /^\s*/

compile_parser = (data, settings)->
  settings = _.defaults {}, settings, parser_compiler_options
  # find the return groups
  data = data.replace settings.return_expr, (match, contents, offset)->
    # split with the regex
    contents = contents.replace settings.inside, (match, key, params)->
      parts = ["_type: \"#{key}\""]
      for param in params.split /\s*,\s*/
        parts.push "#{param}: #{param}"
      parts.join(', ')


    out = "{ return { #{contents}  }; }"
    out

  # build the pegjs parser from the compiled stuff
  PEG.buildParser( data )


rebuild_parser = (grammar_path, callback)->
  fs.readFile grammar_path, encoding: 'UTF-8', (err, data)->
    throw err if err
    parser = compile_parser data
    say.status_v 'grammar', grammar_path
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
  say.error "syntax_error", "#{filename}(#{err.line}:#{err.column}): #{err.message}"

_.extend exports,
  # Create a parser with a helper
  with_parser: (path, callback)->
    rebuild_parser path, (parser)->
      callback( new ParserHelper(parser) )




