async = require 'async'
templater = require '../templater'


makeCppFile = (dir, templateName, outputName, args, callback)->
  tpl = templater.makeTemplate templateName
  dir.output_file outputName, tpl( args... ), (err, path, contents)->
    callback(err, path)



# Builder for the C++ output
module.exports = cppPackageBuilder = (pack, dir, options, callback)->

  async.parallel [
    (callback)-> makeCppFile( dir, 'cpp/templates/types', "#{pack.name}_types.h", [pack], callback )
    (callback)-> makeCppFile( dir, 'cpp/templates/package', "#{pack.name}.cc", [pack], callback )
    (cb)-> makeCppFile( dir, 'cpp/templates/test', "test.cc", [pack], cb )



  ], (err, results)->
    callback( err, results )



  #callback( null, [dir.normalizedFileName(), dir.normalizedFilePath()] )
