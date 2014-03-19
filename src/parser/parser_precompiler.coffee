_ = require 'underscore'
fs = require 'fs'
path = require 'path'
vm = require 'vm'

crypto = require('crypto')

PEG = require 'pegjs'
async = require 'async'
winston = require 'winston'

GrammarPreprocessor = require './grammar_preprocessor'

compile_peg = (data, callback)->
  parser_src = null
  err = null
  try
    parser_options =
      output: "source"
      exportVar: 'module.exports'
      cache: false
      optimize: 'speed'
      plugins: []
    parser_src = PEG.buildParser( data.text, parser_options )
  catch e
    err = e
  callback( err, { path: data.path, text: parser_src } )

preprocess_grammar = (data, callback)->
  callback( null, { path: data.path, text: @preprocessor.processGrammar( data.path, data.text ) } )




class ParserPrecompiler
  constructor: ()->
    @preprocessor = new GrammarPreprocessor


  compile: (path, callback)->
    @generate path, (err, code)=>
      callback( err, null ) if err
      @run code, (err, parser)->
        callback( err, parser )


  generate: (path, callback)->
    compile_source = async.compose(
      compile_peg
      _.bind( preprocess_grammar, @ )
    )
    fs.readFile path, encoding: "UTF-8", (err, data)->
      return callback(err, null) if err
      compile_source path:path, text: data, (err, src)->
        text = if err then "" else src.text
        callback(err, src.text)



  run: (code, callback)->
    # eval the parser
    err = null
    parser = null
    try
      parser = vm.runInNewContext( code )
    catch e
      err = e
    callback( err, parser )


  #cache_get: (obj, opts)->
    #_.defaults( opts, generate: undefined, success: undefined  )

    #sha256 = crypto.createHash('sha256')
    #sha256.update( JSON.stringify(obj) )
    #key = sha256.digest('hex')

    #file_path = path.join( @tmp_dir, "#{key}.pegjs" )
    #fs.exists file_path, (exists)->
      #exists = false
      #contents = null
      #if exists
        #fs.readFile file_path, encoding: "UTF-8", (err, data)->
          #winston.info "getting from cache: #{file_path}"
          #opts.success( err, data )
      #else
        #opts.generate (err, data)->
          #fs.writeFile file_path, data, (err)->
            #winston.info "saved to cache: #{file_path}"
            #opts.success( err, data )


module.exports = ParserPrecompiler
