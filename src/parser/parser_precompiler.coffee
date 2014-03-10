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
  console.log "got peg data"
  parser_src = null
  err = null
  try
    parser_options = output: "source"
    parser_src = PEG.buildParser( data.text, parser_options )
  catch e
    err = e
  #console.log "peg:", err, parser_src
  callback( err, { path: data.path, text: parser_src } )

preprocess_grammar = (data, callback)->
  console.log "preprocess"
  callback( null, { path: data.path, text: @preprocessor.processGrammar( data.path, data.text ) } )




class ParserPrecompiler
  constructor: (@tmp_dir)->
    @preprocessor = new GrammarPreprocessor


  compile: (path, callback)->
    compile_source = async.compose(
      compile_peg
      _.bind( preprocess_grammar, @ )
    )
    fs.stat path, (err, stat)=>
      @cache_get { path: path, mtime: stat.mtime.getDate() },

        generate: (finished)->
          fs.readFile path, encoding: "UTF-8", (err, data)->
            throw err if err
            compile_source path:path, text: data, (err, src)->
              throw err if err
              finished(err, src.text)

        success: (err, code)->
          throw err if err
          # eval the parser
          parser = vm.runInNewContext( code )
          callback( err, parser )
          

  cache_get: (obj, opts)->
    _.defaults( opts, generate: undefined, success: undefined  )

    sha256 = crypto.createHash('sha256')
    sha256.update( JSON.stringify(obj) )
    key = sha256.digest('hex')

    file_path = path.join( @tmp_dir, "#{key}.pegjs" )
    fs.exists file_path, (exists)->
      exists = false
      contents = null
      if exists
        fs.readFile file_path, encoding: "UTF-8", (err, data)->
          winston.info "getting from cache: #{file_path}"
          opts.success( err, data )
      else
        opts.generate (err, data)->
          fs.writeFile file_path, data, (err)->
            winston.info "saved to cache: #{file_path}"
            opts.success( err, data )


module.exports = ParserPrecompiler
