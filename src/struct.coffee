_ = require 'underscore'

class Struct
  _isStruct: true

  requires: {}
  constructor: (attrs = {})->
    
    @_checkForMissingFields attrs
    # if everything is ok, set the attribtues
    @attributes = {}
    @set attrs

  # update the attributes
  set: (attrs)->
    _.defaults( @attributes, attrs )

  # recursively convert the Struct to JSON
  toJSON: ->
    o = {}
    for k,v of @attributes
      o[k] = switch
        # recurse for struct
        when v in [undefined, null] then v
        when v._isStruct then v.toJSON()
        else v
    o


  _checkForMissingFields: (attrs)->
    # check for missing fields
    missing_fields = _.filter _.keys(@requires),  (e)-> attrs[e] == undefined
    if missing_fields.length > 0
      throw new Error("Required fields #{ JSON.stringify(missing_fields)} missing from #{ JSON.stringify(@attributes) }")
    return

module.exports = Struct
