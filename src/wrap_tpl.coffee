_ = require 'underscore'
_s = require 'underscore.string'
coffee = require 'coffee-script'

async = require 'async'
fs = require 'fs'
path = require 'path'
vm = require 'vm'

util = require './util'

wrap_tpl = exports

class WrapException
  constructor: (@group, @message)->

options =
  basedirs: [ path.join(__dirname, 'templates'), path.join(__dirname, "tpl") ]
  extension: ".wrap.coffee"

  # The target width of the resulting document in characters
  width: 40

  indentStr: '    '

class Stack
  constructor: ->
    @levels = [[]]


  current: -> _.last(@levels)

  # append a list of tokens to the current level
  tokens: (tokens...)->
    @current().push(tokens...)

  with_level: (callback)->
    outer_frame = @current()
    new_frame = []
    @levels.push new_frame
    callback() if callback
    @levels.pop()
    # store the frame in the parent frame
    @tokens new_frame



# Load a wrap template
load_wrap_file = (filename, callback)->
  possible_file_name = (b)-> path.join(b, "#{filename}#{options.extension}")
  # find a matching file
  possible_locations = _.map( options.basedirs, possible_file_name )
  async.detectSeries possible_locations, fs.exists, (f)->
    return parse_wrap_file(f, callback)


parse_wrap_file = (file_path, callback)->
  fs.readFile file_path, encoding: "UTF-8", (err, contents)->
    # compile down to coffeescript
    coffee_options = bare: true
    compiled = coffee.compile( contents, coffee_options )
    wrapped_fn = vm.createScript( compiled, file_path )
    # the function to run the template
    tpl_func = (data)->
      # The stack used to store the results
      stack = new Stack
      # the function to create a wrap
      wrap_fn = ( opts, callback )->
        callback = callback ? opts
        # and the start and end tokens need to go in the start frame
        stack.tokens opts.start if opts.start
        stack.with_level ->
          stack.tokens { _separator: true, string: opts.sep } if opts.sep
          callback()
        stack.tokens opts.end if opts.end

      # the function to write to a new buffer
      out_fn = (strs...)-> stack.tokens(strs...)
      # some helpers
      helpers = {
        # add underscore for easy usage
        _: _
        out: out_fn
        wrap: wrap_fn
        log: console.log
      }
      # create the context
      context = _.extend( helpers, data )
      # run via the cached function
      wrapped_fn.runInNewContext( context )
      render( stack.current() )

    # return the wrapped template function
    callback( tpl_func )


apply_separators = (wrap)->
  separator = undefined
  separator = wrap[0].string if wrap[0]._separator

  tokens = for el in wrap
    switch
      when _.isArray( el ) then apply_separators(el)
      when el._separator then
      else el

  #if separator
    #tokens = util.array_join(tokens, separator)
  {tokens: tokens, separator: separator }

class RenderBuffer
  constructor: (@options)->
    @lines = []
    @line = []
    @indent = 0

  out: (strs...)->
    @line.push strs...


  nl: -> @flush()

  flush: ->
    return if @line.length == 0
    @lines.push {indent: @indent, tokens: @line}
    @line = []


  with_indent: (fn)->
    @flush()
    @indent += 1
    fn()
    @indent -= 1


  toString: ()->
    @flush()
    opts = options
    make_indent = (width)-> _s.repeat( opts.indentStr, width )
    line_mapper = (l)-> [ make_indent( l.indent - 1 ), l.tokens...].join('')
    mapped_lines = _.map( @lines, line_mapper)
    console.log mapped_lines
    mapped_lines.join("\n")


calculate_lengths = (wrap)->

render_outer = (wrap)->
  #console.log JSON.stringify(wrap, null, 2)
  render_inner( wrap )

render_inner = (wrap)->
  console.log "Wrap innder:", wrap
  elements = []
  # collect all elements, recurse depth-first
  for el in wrap.tokens
    if _.isArray(el)
      elements.push render_inner(el)
    else
      elements.push el

  # check the length
  str_len = (memo, str)->
    memo + switch
      when _.isString( str ) then str.length
      when str.el
        if str._nl then 0 else _.reduce( str.el, str_len, 0 )

  joined_len = _.reduce elements, str_len, 0
  # prepare the output
  o = { _nl:false,  el: elements, sep: wrap.separator }
  # if the joined string is longer then the target width
  # we join the string by a newline
  if joined_len > options.width
    o._nl = true
  # return the node
  o

merge_render_output = (input)->
  #unless buffer
  #console.log JSON.stringify(input, null, 2)
  # create the buffer if necessary
  buffer = new RenderBuffer(options)
  _merge_render_output( input, buffer )
  buffer.toString()


_merge_render_output = (input, buffer)->
  # check the joiner
  wrap_fn = (fn)-> fn()
  wrap_fn = _.bind( buffer.with_indent, buffer ) if input._nl

  wrap_fn ->
    return unless input.el
    for t in input.el
      switch
        when _.isString(t) then buffer.out t
        else _merge_render_output(t, buffer)
      buffer.nl() if input._nl



#render = _.compose( merge_render_output, render_inner )
render = _.compose( merge_render_output, render_outer, apply_separators )

_.extend wrap_tpl,
  options: options
  load: load_wrap_file
  render: render
