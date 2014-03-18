_       = require 'underscore'
fs      = require 'fs-extra'
path    = require 'path'
winston = require 'winston'


is_tc_file = (filename)->
  path.extname(filename) == '.tc'

class Root
  constructor: (@dir)->
    throw new Error("Package root directory not set.") unless @dir
    @packages = {}
    @output_dir = path.join( @dir, ".tc" )


  add: (package_location)->
    @packages[package_location.name] = package_location
    package_location.root = @
    package_location

  get: (name)-> @packages[name]
  getOrCreate: (name)->
    return @packages[name] if @packages[name]
    @add(new PackageDir(name))


class PackageDir
  constructor: (@name)->


  dir: -> @_dir ||= path.join( @root.dir, @name )
  output_dir: -> @_output_dir ||= path.join( @root.output_dir, @name )

  # Save something to the output directory
  output_file: (filename, contents, callback)->
    # make sure callback exists
    callback = callback ? (err)->
    # wirte ut via fs-extra
    file_path = path.join( @output_dir(), filename )
    fs.outputFile file_path, contents, (err)->
      if err
        winston.error("Error while trying to write '#{file_path}': #{err}", err)
      else
        winston.info("Written #{file_path}")
      callback(err)


  # Save something to the output dir as JSON
  output_json: (filename, obj)->
    @output_file( filename, JSON.stringify(obj, null, 2) )

  # Does the package directory exist?
  must_exist: (callback)->
    package_path = @dir()
    fs.exists package_path, (err, res)->
      callback(err, res)


  with_tc_files: (opts, callback)->
    callback = callback ? opts
    _.defaults opts, package_files: true, test_files: false
    package_path = @dir()
    package_dir = @
    @must_exist (exists)->
      return callback([]) unless exists
      # now the directory exists
      fs.readdir package_path, (err, files)->
        # the current map function to filter the file list
        filename_eraser = (fn)-> if is_tc_file(fn) then { path: path.join(package_path, fn), file: fn, dir: package_dir } else null
        # map to all file names
        all_files = _.chain( files ).map( filename_eraser ).without( null ).value()
        callback(all_files)





module.exports =
  Root: Root
  PackageDir: PackageDir
