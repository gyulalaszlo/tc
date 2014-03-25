async = require 'async'
templater = require '../templater'


makeCppFile = (dir, templateName, outputName, args, callback)->
  tpl = templater.makeTemplate templateName
  dir.output_file outputName, tpl( args... ), (err, path, contents)->
    callback(err, path)
  


# Builder for the C++ output
module.exports = cppPackageBuilder = (pack, dir, options, callback)->
  #console.log pack.types
  #typesTpl = templater.makeTemplate 'cpp/templates/types'
  #console.log typesTpl( pack )

  async.parallel [
    (callback)-> makeCppFile( dir, 'cpp/templates/types', "#{pack.name}_types.h", [pack], callback )



  ], (err, results)->
    callback( err, results )



  #callback( null, [dir.normalizedFileName(), dir.normalizedFilePath()] )
