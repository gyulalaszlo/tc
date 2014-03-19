coffee = require('coffee-script/register')
fs = require 'fs-extra'

option '-o', '--output [DIR]', 'directory for compiled code'

task 'build:parser', 'rebuild the Jison parser', (options) ->
    ParserPrecompiler = require './src/parser/parser_precompiler'
    precompiler = new ParserPrecompiler()
    precompiler.generate 'grammar/tc.peg', (err, src)->
      throw err if err
      dir  = options.output or 'lib'
      contents = "module.exports = " + src + ";\n"
      fs.outputFile "#{dir}/parser.js", contents
