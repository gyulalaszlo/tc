fs = require 'fs'
path =require 'path'
_ = require 'underscore'
_s = require 'underscore.string'

# helper to split the _type and _group of a key in the return tree tokens
split_key_path = (key)->
  key_path = _s.words( key, /\./  )
  type = _.last( key_path )
  group = 'default'
  group = key_path[0..-2].join('.') if key_path.length > 1
  # return as an object, ready to use
  { _type:type, _group:group }

class GrammarPreprocessor

  # Some private helpers
  ########################################

  # When customizing templateSettings, if you don’t want to define an
  # interpolation, evaluation or escaping regex, we need one that is guaranteed not
  # to match.
  noMatch = /(.)^/

  parser_compiler_options =
    return_expr: /->\{\{(.*?)\}\}/g
    inside: /^\s*([a-zA-Z][a-z\/\.A-Z_]*)\s+with\s+(.*?)\s*$/

    include_expr: /\{\{\s*include\s+([a-z_]+)\s*\}\}/

  ########################################

  constructor: (settings)->
    @settings = _.defaults {}, settings, parser_compiler_options
    @compile_matchers @settings

    # store the tree tokens
    @tree_token_groups = {}


  processGrammar: (grammar_path, data)->
    # find the directory to look for partials in
    include_dir = path.dirname( grammar_path ) 
    # Compile the parser source
    data = data.replace @matcher, (match, returner, includer, offset)=>
      switch
        when returner then @on_returner( returner )
        when includer then @on_includer( includer, include_dir )
    # return the compiled stuff
    data

  # ->{{ XY with foo, bar }}
  on_returner: (input)->
    # split with the regex
    returner = input.replace @returner_inside_matcher, (match, key, params)->
      # the return objects fields (has to be a string array
      # because there are variables in play
      parts = []
      # add the parsed data from the key
      for k, v of split_key_path( key )
        parts.push "#{k}: #{JSON.stringify(v)}"
      # add the parameters to the proper keys
      for param in params.split /\s*,\s*/
        parts.push "#{param}: #{param}"
      # conver to a string
      parts.join(', ')

    "{ return { #{returner}  }; }"

  # {{ include xy }}
  on_includer: ( input, include_dir )->
    file_name = "_#{input}.peg"
    file_path = path.join( include_dir, file_name )
    # read the file contents to a string
    if !fs.existsSync( file_path )
      throw new Error("Cannot open included grammar: #{ file_name } (included from #{grammar_path}, at offset: #{offset}")
    contents = fs.readFileSync file_path, encoding: "UTF-8"
    # return the preprocessed contents
    @processGrammar( file_path, contents )
    #return preprocess_parser_data( file_path, contents, settings )


  ########################################

  compile_matchers: (settings)->
    @matcher = new RegExp( [
      (settings.return_expr || noMatch).source
      (settings.include_expr || noMatch).source
      #(settings.evaluate || noMatch).source
    ].join('|'), 'g');

    @returner_inside_matcher = settings.inside

module.exports = GrammarPreprocessor
