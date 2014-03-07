_ = require 'underscore'
coffee = require 'coffee-script'

async = require 'async'
fs = require 'fs'
path = require 'path'
vm = require 'vm'

util = require './util'

wrap_tpl = exports

class Wrap
  constructor: (@start, @end, @separator, @contents)->

class WrapException
  constructor: (@group, @message)->

make_wrap = (opts, callback )->
  _.defaults( opts,{ _wrap: true, start:'', end:'', sep:null, before:null, after: null, contents: [] })
  if callback
    switch
      when _.isFunction(callback) then opts.contents = callback()
      when _.isArray(callback) then opts.contents = callback
  opts

options =
  basedirs: [ path.join(__dirname, 'templates'), path.join(__dirname, "tpl") ]
  extension: ".wrap.coffee"



load_wrap_file = (filename, callback)->
  possible_file_name = (b)-> path.join(b, "#{filename}#{options.extension}")
  # find a matching file
  possible_locations = _.map( options.basedirs, possible_file_name )
  async.detectSeries possible_locations, fs.exists, (f)->
    return parse_wrap_file(f, callback) 

    # fail if the results are not found
    throw new WrapException( "fs.exists", "Cannot find wrap file '#{filename}' in #{JSON.stringify(options.basedirs)}" )
  #file_path = path.join( basedir, filename )


parse_wrap_file = (file_path, callback)->
  fs.readFile file_path, encoding: "UTF-8", (err, contents)->
    coffee_options = bare: true
    compiled = coffee.compile( contents, coffee_options )
    wrapped_fn = vm.createScript( compiled, file_path )
    # add some helpers
    tpl_func = (data)->
      stack = [[]]
      # the function to create a wrap
      wrap_fn = ( opts, callback )->
        callback = callback ? opts
        frame = _.last(stack)
        frame.push opts.start if opts.start
        new_frame = []
        if opts.sep
          console.log opts, stack
          new_frame.push {_separator: true, string: opts.sep } if opts.sep
        # add the new frame
        stack.push new_frame
        #console.log stack
        callback() if callback
        # remove new_frame
        stack.pop()
        # store back the frame
        frame.push new_frame
        frame.push opts.end if opts.end

      # the function to write to a new buffer
      out_fn = (strs...)-> _.last(stack).push(strs...)
      helpers = {
      }
      # create the context
      context = _.extend( { _: _, wrap: wrap_fn, out: out_fn, log: console.log }, helpers, data )
      # run via the cached function
      wrapped_fn.runInNewContext( context )
      _.last(stack)
      #vm.runInNewContext( compiled, { _: _,  wrap: make_wrap },  file_path )
    #compiled_contents = coffee.eval( tpl.join("\n"), coffee_options )
    #console.log compiled_contents
    callback( tpl_func )



render = (wrap)->
  MAX_LEN = 80

  current_line = []
  len = 0
  indent = 0

  separator = undefined
  separator = wrap[0].string if wrap[0]._separator

  tokens = for el in wrap
    switch
      when _.isArray( el ) then render(el)
      when el._separator then
      else el


  if separator
    tokens = util.array_join(tokens, separator)

  tokens

  #while len < MAX_LEN
    #len +=


_.extend wrap_tpl,
  options: options
  load: load_wrap_file
  render: render
