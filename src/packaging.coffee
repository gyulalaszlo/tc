_       = require 'underscore'
_s      = require 'underscore.string'
fs      = require 'fs-extra'
path    = require 'path'
winston = require 'winston'

Bench   = require './bench'


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
    #winston.info("Starting to write #{file_path}")
    bench = new Bench "write file '#{file_path}' [#{contents.length} bytes]", true
    fs.outputFile file_path, contents, (err)->
      if err
        winston.error("Error while trying to write '#{file_path}': #{err}", err)
      else
        bench.stop()
      callback(err, file_path, contents) if callback


  # Save something to the output dir as JSON
  output_json: (filename, obj, args...)->
    @output_file( filename, JSON.stringify(obj, null, 2), args... )

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
      unless exists
        return callback(new Error("Package directory '#{package_path}' for '#{@name}' does not exist."), [])
      # now the directory exists
      fs.readdir package_path, (err, files)->
        return callback(err, []) if err
        # the current map function to filter the file list
        filename_eraser = (fn)-> if is_tc_file(fn) then { path: path.join(package_path, fn), file: fn, dir: package_dir } else null
        # map to all file names
        all_files = _.chain( files ).map( filename_eraser ).without( null ).value()
        callback(null, all_files)



  normalizedFileName: -> "_.#{@name}.normalized.json"
  normalizedFilePath: -> path.join( @output_dir(), @normalizedFileName() )

  outputNormalizedFile: ( contents, callback)->
    @output_json @normalizedFileName(), contents, callback


  readNormalizedFile: (callback)->
    fs.readJson @normalizedFilePath(), (err, contents)->
      callback( err, contents )






module.exports =
  Root: Root
  PackageDir: PackageDir
