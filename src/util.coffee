fs      = require 'fs-extra'
path    = require 'path'
winston = require 'winston'


capitalA = "A".charCodeAt(0)
capitalZ = "Z".charCodeAt(0)

# A wrapper for mkdir_p like thor's empty_directory
empty_directory = (path)->
  return if fs.existsSync( path )
  fs.mkdirsSync path
  winston.info "created directory: #{path}"

# Helper to write out a file
write_file = (file, contents)->
  # create the directory if it doesnt exist
  empty_directory path.dirname(file)
  # and write our file
  fs.writeFile file, contents, (err)->
    throw err if err
    winston.info "written: #{file}"

# Check if a file is a tc file
is_tc_file = (filename)->
  path.extname(filename) == '.tc'

type_name = (t)->
  key = if t._type is 'ctype' then 'raw' else 'name'
  t[key]

is_published = (t)->
  # The first character of the name is an uppercase letter
  capitalA <= t.charCodeAt(0) <= capitalZ


# returns the array with separator elements injected between
# the existing elements
array_join = (arr, separator)->
  o = []
  for a, i in arr
    o.push a
    o.push separator unless i == (arr.length - 1)
  o


class_method_name = (klass, method_name)->
  return switch method_name
    when "Constructor" then klass.name
    when "Destructor" then "~#{klass.name}"
    else method_name


module.exports =

  empty_directory: empty_directory
  write_file: write_file
  is_tc_file: is_tc_file
  type_name: type_name
  is_published: is_published
  array_join: array_join
  class_method_name: class_method_name
