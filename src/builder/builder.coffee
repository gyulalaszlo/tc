async = require 'async'
# All the generators are stored here
generators = {}
# Builder for the C++ output
generators.cpp = require './cpp/cpp'

exports.buildOutput = buildOutput = (root, packageList, options, callback)->
  # Try to load the generator
  {generator, err} = getGenerator( options.generator )
  return callback( err, null ) if err
  # Load a package
  packageLoaderFn = (name, callback)->
    packageDir = root.getOrCreate name
    # Read the normalized file and package it with the directory
    # to write the files to
    packageDir.readNormalizedFile (err, pkg)->
      callback(err, {dir: packageDir, data: pkg})

  callGenerate = (packData, callback)->
    generator( packData.data, packData.dir, options, callback )

  async.map packageList, packageLoaderFn, (err, packages)->
    async.map packages, callGenerate, (err, files)->
      callback(err, files)


# Get the generator for a name
getGenerator = (generatorName)->
  err = null
  # check for the generator
  generator = generators[generatorName]
  unless generator
    err = new Error("Cannot find generator with name '#{generatorName}'")
  { generator: generator, err: err }


