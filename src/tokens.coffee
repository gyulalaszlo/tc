
# get the source position of a token
source_position = (pos)->
  "(#{pos.line}:#{pos.column})"

class TokenError
  constructor: (token, message, text)->
    Error.captureStackTrace this, TokenError
    #@stack = Error.prepareStackTrace(error, structuredStackTrace)
    # initialize after the stack is captured
    @token = token
    @name = "TokenError"
    @message = message
    @text = @token.text or text

  toString: ->
    "(#{source_position @token.start} '#{@text}'): #{@message}"


module.exports =
  TokenError: TokenError
  source_position: source_position
