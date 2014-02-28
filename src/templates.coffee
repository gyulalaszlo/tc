_ = require 'underscore'

fs = require 'fs'
path = require 'path'

all_tpl = {}

with_tpl = (filename, callback)->
  file_path = "#{__dirname}/templates/#{filename}"
  abs_path = path.normalize(file_path)
  return callback( all_tpl[abs_path] ) if all_tpl[abs_path]

  fs.readFile file_path, encoding: 'UTF-8', (err, data)->
    throw err if err
    tpl = _.template data
    all_tpl[file_path] = tpl
    callback(tpl)


render_tpl = (filename, obj, callback)->
  with_tpl filename, (tpl)->
    callback tpl( obj )

is_valid_token = (t)->
  return false if t in [null, '']
  return false if t.length && t.length == 0
  true

filter_token_list = (list)->
  valid_tokens = []
  for t in list
    valid_tokens.push t if is_valid_token t
  valid_tokens


class CTpl
  constructor: (@_indent_str="    ")->
    @_indent = 0
    @_buffer = []

  l: (txt)->
    @_buffer.push [@_indent_chars(), txt].join('')


  tokens: (list...)->
    o = []
    for t in list
      switch t
        when null then null
        when '' then null
        when ';' then o[o.length - 1] += ';'
        else o.push t
    @l o.join(' ')


  wrapped: (start, end, contents...)->
    # first filter only the valid tokens
    valid_tokens = filter_token_list contents
    # return a blank wrapper if no valid tokens available
    return "#{start}#{end}" if valid_tokens.length == 0

    o = [ start ]
    o.push t for t in valid_tokens
    o.push end
    o.join(' ')

  indent: (txt, callback)->
    @l(txt)
    @_indent++
    callback()
    @_indent--

  braces: (txt, callback)->
    @indent( "#{txt} {", callback )
    @l("}")

  toString: -> @_buffer.join("\n")


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
  with_tpl: with_tpl
  render_tpl: render_tpl
  c_tpl: make_c_tpl
  run_c_tpl: run_c_tpl



