_ = require 'underscore'
async = require 'async'
fs = require 'fs-extra'
path = require 'path'

coffee = require 'coffee-script/register'

option '-o', '--output [DIR]', 'directory for compiled code'

build_parser = (builder_class, grammar_file, options, callback)->
  callback = callback ? options
  _.defaults( options, requires: {}, output: 'lib' )
  # make the preompiler
  precompiler = new builder_class()
  precompiler.generate grammar_file, (err, src)->
    return callback(err, null) if err
    output_path = path.join( options.output, "#{path.basename( grammar_file, '.pegjs')}.peg.js" )
    # add the node code
    contents = []
    # add any require statements
    for local_name, import_path of options.requires
      contents.push "var #{local_name} = require(#{JSON.strinigfy(import_path)});"
    # wrap the parser in a node exports wrapper
    contents.push "module.exports =", src, ";\n"
    # write the file and create the directory if needed
    fs.outputFile output_path, contents.join(' '), (err)->
      callback(err, output_path)

task 'build:parser', 'rebuild the Jison parser', (options) ->
  ParserPrecompiler = require './src/parser/parser_precompiler'
  build_parser_fn = (name, callback)-> build_parser( ParserPrecompiler, name, options, callback )
  precompiler = new ParserPrecompiler()
  async.map ['grammar/tc.pegjs', 'grammar/tc2.pegjs'], build_parser_fn, (err, files)->
    if err
      console.error err
      console.error err.stack
    else
      console.log "Written: ", files
  #precompiler.generate 'grammar/tc.peg', (err, src)->
