_ = require 'underscore'

as_json = (what)->
  switch
    when _.isBoolean(what) || _.isNumber(what) || _.isString(what) then what
    when _.isArray(what) then ( as_json(w) for w in what )
    when _.isObject(what)
      # serialize via the build-in stuff
      if what.as_json
        res = what.as_json()
        as_json(res)
      else
        o = {}
        ( o[k] = as_json(v) for k,v of what )
        o

# Base class for serialization
class JsonSerializable
  as_json: (data...)-> _.extend( data...)

# Helper base class to serialize stuff with a name
class JsonSerializableWithName extends JsonSerializable
  as_json: (data...)-> super({ name: @name }, data...)


module.exports =
    base: JsonSerializable
    with_name: JsonSerializableWithName
    as_json: as_json
