
# get the source position of a token
source_position = (pos)->
  console.log pos
  "(#{pos.line}:#{pos.column})"

class TokenError
  constructor: (token, message)->
    Error.captureStackTrace this, TokenError
    #@stack = Error.prepareStackTrace(error, structuredStackTrace)
    # initialize after the stack is captured
    @token = token
    @name = "TokenError"
    @message = message

  toString: ->
    "(#{source_position @token.start} '#{@token.text}'): #{@message}"

module.exports =
  TokenError: TokenError
  source_position: source_position
