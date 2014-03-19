_s             = require 'underscore.string'
winston       = require 'winston'

class Bench
  constructor: (@text, @hide_start=false)->
    @start = @diff = process.hrtime()
    if @text && !hide_start
      winston.info "--> #{@text}"

  stop: ->
    @diff = process.hrtime(@start)
    if @text
      winston.info "#{ if @hide_start then '' else '<-- '}#{@text} (in #{ _s.numberFormat( @ms(), 2)} ms)"
    @diff

  ms: ->
    @diff[0] * 1e3 + (@diff[1] * 1e-6)

module.exports = Bench
