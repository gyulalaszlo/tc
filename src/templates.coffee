_ = require 'underscore'

is_valid_token = (t)->
  return false if t in [null, '']
  return false if t.length && t.length == 0
  true

filter_token_list = (list)->
  valid_tokens = []
  for t in list
    valid_tokens.push t if is_valid_token t
  valid_tokens

indent_str = (amount, str)->
  o = []
  `for(var i=0; i < amount; ++i) { o.push(str); }`
  o.join ''

NEWLINE = 1
INDENT = 2
OUTDENT = 3

class CTokenListFilter

class NewLineFilter extends CTokenListFilter
  filter: (tokens)->
    o = []
    for t in tokens
      switch(t)
        when ';' then o.push ";", "\n"
        when INDENT then o.push INDENT, "\n"
        when OUTDENT then o.push OUTDENT, "\n"
        when NEWLINE
          o.push "\n"
        else
          o.push t
    o

class IndentFilter extends CTokenListFilter
  @indent_str = "  "
  filter: (tokens)->
    o = []
    indent = 0
    for t in tokens
      switch(t)
        when INDENT then indent++
        when OUTDENT then indent--
        when "\n"
          o.push "\n", indent_str(indent, IndentFilter.indent_str)
        else
          o.push t
    o

class SpaceFilter extends CTokenListFilter
  filter: (tokens)->
    o = []
    needs_space = false
    for t in tokens
      needs_space = false if t == ';'
      o.push " " if needs_space
      o.push t
      switch
        when t[t.length-1] == ' '
          needs_space = false
        else
          needs_space = true
    o


all_filters = [ new NewLineFilter, new IndentFilter, new SpaceFilter ]

class CTokenList
  constructor: (@indent_str="    ")->
    @tokens = []

  add: (tokens)->
    for t in tokens
      @tokens.push t if is_valid_token(t)

  toString: ->
    tokens = @tokens
    tokens = f.filter(tokens) for f in all_filters
    tokens.join('')


class CTpl
  constructor: (@_indent_str="    ")->
    @_tokens = new CTokenList

  l: (tokens...)->

    #@_buffer.push [@_indent_chars(), txt].join('')
    @_tokens.add tokens #.concat( [NEWLINE]  )


  tokens: (list...)->
    o = []
    for t in list
      switch t
        when null then
        when '' then
        else o.push t
    @_tokens.add list


  wrap: (start, end, contents...)->
    # first filter only the valid tokens
    valid_tokens = filter_token_list contents
    # return a blank wrapper if no valid tokens available
    return "#{start}#{end}" if valid_tokens.length == 0

    o = [ start ]
    o.push t for t in valid_tokens
    o.push end
    o.join(' ')

  indented: (tokens...)->
    # skip empty blocks
    return if tokens.length == 0
    # get the callback (the last arg)
    callback = tokens[ tokens.length - 1 ]
    throw new Error("Invalid callback - tokens: #{JSON.stringify(tokens)}") unless _.isFunction( callback )
    @_tokens.add tokens[..-2]
    @_tokens.add [INDENT]
    callback()
    @_tokens.add [OUTDENT]


  wrapped: (start, end, tokens...)->
    # skip empty blocks
    if tokens.length == 0
      @_tokens.add [ start, end ]
      return
    # get the callback (the last arg)
    callback = tokens[ tokens.length - 1 ]
    text_tokens = tokens[..-2]
    @indented( text_tokens.concat([start])..., callback )
    @_tokens.add([end])

  braces: (txt, callback)->
    @indent( "#{txt} {", callback )
    @l("}")
    #@_tokens.add ["}"]


  _indent_chars: ->
    o = []
    `for(var i=0; i < this._indent; ++i) { o.push(this._indent_str); }`
    o.join ''


make_c_tpl = (args...)->
  new CTpl(args...)

run_c_tpl = (func, data)->
  c = make_c_tpl()
  func( c, data )
  c

_.extend exports,
  c_tpl: make_c_tpl
  run_c_tpl: run_c_tpl



