_ = require 'underscore'
_s = require 'underscore.string'
coffee = require 'coffee-script'

async = require 'async'
fs = require 'fs'
path = require 'path'
vm = require 'vm'

util = require 'util'

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


class RenderBuffer
  constructor: (@options)->
    @lines = []
    @line = []
    @indent = 0

  out: (strs...)-> @line.push strs...


  nl: -> @flush()

  flush: ->
    return unless @line.length > 0
    @lines.push {indent: @indent, tokens: @line}
    @line = []


  with_indent: (amt, fn)->
    @add_indent amt
    fn()
    @add_indent amt * -1

  add_indent: (amt)->
    return if amt == 0
    @flush()
    @indent += amt


  toString: ()->
    @flush()
    opts = options
    make_indent = (width)-> _s.repeat( opts.indentStr, width )
    line_mapper = (l)-> [ make_indent( l.indent ), _s.trim( l.tokens.join('') ) ].join('')
    mapped_lines = _.map( @lines, line_mapper)
    mapped_lines.join("\n")


class WrapRenderer

  constructor: (@max_line_length)->


  add_level: (lvl)->
    @calc_length( lvl )
    @check_merge( lvl )
    @create_merge( lvl )

  calc_length: (lvl)->
    # the length of onlt the string tokens
    local_len = 0
    # the length with the children included
    len = 0
    for e in lvl.tokens
      switch
        when e.tokens
          len += @calc_length(e)
        else
          len += e.length
          local_len += e.length
    lvl._length = len
    lvl._local_length = local_len
    len

  check_merge: (lvl, indent = 0)->
    # a level should be nl-wrapped if any of its children are NL wrapped
    # or the line length exceeds the available
    INDENT_WIDTH = 4
    LINE_WIDTH = 80
    indent_amt = INDENT_WIDTH * indent
    # if the levels length exceds the line width
    if lvl._length + indent_amt > LINE_WIDTH
      lvl._nl = true
      indent += 1
    else
      lvl._nl = false
    # add break to the signaled ones
    lvl._nl = true if lvl.break
    for token in lvl.tokens
      if token.tokens
        @check_merge( token, indent )
    lvl


  create_merge: (lvl)->
    buffer=new RenderBuffer
    @_do_merge( lvl, buffer )
    buffer

  _do_merge: (lvl, buffer)->
    # output strings as-is
    #return buffer.out( lvl ) unless lvl.tokens
    indent_amt = if lvl._nl then 1 else 0
    indent_amt = 0 if lvl.inline
    separator = lvl.separator
    separator = undefined if separator == " " and lvl._nl

    last_idx = lvl.tokens.length - 1
    for t,i in lvl.tokens
      switch
        when t.tokens
          buffer.with_indent indent_amt, =>
            @_do_merge t, buffer
            buffer.nl() if lvl._nl && lvl.inline
        when t._line
          buffer.nl()
          buffer.out t.string
          buffer.nl()
        else
          buffer.out t

      buffer.out separator if separator && i != last_idx


find_wrap_file = (filename, callback)->
  possible_file_name = (b)-> path.join(b, "#{filename}#{options.extension}")
  # find a matching file
  possible_locations = _.map( options.basedirs, possible_file_name )
  async.detectSeries possible_locations, fs.exists, (f)->
    callback(f)

# Load a wrap template
load_wrap_file = (filename, callback)->
  find_wrap_file filename, (f)->
    throw err unless f
    #possible_file_name = (b)-> path.join(b, "#{filename}#{options.extension}")
    ## find a matching file
    #possible_locations = _.map( options.basedirs, possible_file_name )
    #async.detectSeries possible_locations, fs.exists, (f)->
    return parse_wrap_file(f, callback)

# precompile with coffee-script
precompile_coffee = (contents)->
    coffee_options = bare: true
    coffee.compile( contents, coffee_options )


# precompile (load and coffe-compile) a template file
precompile_tpl = (file_path, callback)->
  fs.readFile file_path, encoding: "UTF-8", (err, contents)->
    throw err if err
    # compile down to coffeescript
    #coffee_options = bare: true
    #compiled = coffee.compile( contents, coffee_options )
    compiled = precompile_coffee( contents ) 
    callback( err, compiled )


# the runner function for templates (binds the helpers)
tpl_runner_fn = (data, callbacks)->
  # The stack used to store the results
  stack = new Stack
  stack.tokens { _inline: true }
  # the function to create a wrap
  wrap_fn = ( opts, callback )->
    callback = callback ? opts
    # and the start and end tokens need to go in the start frame
    stack.tokens opts.start if opts.start
    stack.with_level ->
      stack.tokens { _separator: true, string: opts.sep } if opts.sep
      stack.tokens { _force_break: true } if opts.break
      stack.tokens { _inline: true } if opts.inline
      callback()
    stack.tokens opts.end if opts.end


  inline_fn = (opts, callback)->
    unless callback
      callback = opts
      opts = {}
    opts.inline = true
    wrap_fn( opts, callback)

  exported_symbols = {}

  include_fn = (filename, finish_callback)->
    callbacks.on_include helpers, filename
    exported_symbols[filename]
    #, (err)->
      #finish_callback( exported_symbols[filename] )

  export_fn = (filename, symbols={})->
    exported_symbols[filename] = symbols

  # the function to write to a new buffer
  out_fn = (strs...)-> stack.tokens(strs...)

  line_fn = (str)-> stack.tokens({ _line: true, string: str })
  # some helpers
  helpers = {
    # add underscore for easy usage
    _: _
    _s: _s
    out: out_fn
    line: line_fn
    wrap: wrap_fn
    inline: inline_fn
    log: console.log

    include: include_fn
    exports: export_fn
  }
  # create the context
  context = _.extend( helpers, data )
  # run via the cached function
  callbacks.on_render( context )
  render( stack.current() )


parse_wrap_file = (file_path, callback)->
  precompile_tpl file_path, (err, compiled)->
    wrapped_fn = vm.createScript( compiled, file_path )
    # create an adapter for vm.runInNewContext()
    tpl_func = (data)->
      tpl_runner_fn data,
        on_render: (context)-> wrapped_fn.runInNewContext( context )
        on_include: (context, name, finished_callback)->
          try
            local_path = path.dirname( file_path )
            local_tpl_file = path.join( local_path, "_#{name}.wrap.coffee" )
            contents = fs.readFileSync local_tpl_file, encoding: "UTF-8"
            compiled = precompile_coffee( contents )
            included = vm.createScript( compiled, file_path )
            included.runInNewContext( context )
          catch err
            throw err

    # return the wrapped template function
    callback( tpl_func )

# Filter the list of simple wraps.
convert_input_wrap = (wrap)->
  out = { tokens: [] }
  tokens = out.tokens
  for el in wrap
    switch
      when _.isArray( el ) then tokens.push( convert_input_wrap(el) )
      when el._separator then out.separator = el.string
      when el._force_break then out.force_break = true
      when el._inline then out.inline = true
      else
        tokens.push el

  out


merge_render_output = (input)->
  renderer = new WrapRenderer
  renderer.calc_length input
  renderer.add_level input






render = _.compose( merge_render_output, convert_input_wrap )




_.extend wrap_tpl,
  options: options
  load: load_wrap_file
  render: render
