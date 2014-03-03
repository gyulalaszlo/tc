fs = require 'fs'
path = require 'path'

say = require './say'

module.exports =
  write_file: (file, contents)->
    fs.writeFile file, contents, (err)->
      throw err if err
      say.status "written", file

  # Check if a file is a tc file
  is_tc_file: (filename)->
    path.extname(filename) == '.tc'

  type_name: (t)->
    key = if t._type is 'ctype' then 'raw' else 'name'
    t[key]

  is_published: (t)->
    # The first character of the name is an uppercase letter
    64 < t.charCodeAt(0) < 91


  # returns the array with separator elements injected between
  # the existing elements
  array_join: (arr, separator)->
    o = []
    for a, i in arr
      o.push a
      o.push separator unless i == (arr.length - 1)
    o


  class_method_name: (klass, method_name)->
    return switch method_name
      when "Constructor" then klass.name
      when "Destructor" then "~#{klass.name}"
      else method_name



