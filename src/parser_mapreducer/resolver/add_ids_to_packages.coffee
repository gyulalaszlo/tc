_ = require 'underscore'
async = require 'async'


# NOTE: This method modifies the package data instead of copying it.
addIdsToPackages = (packages, callback)->
  # The function to add ids to a package
  # Call the parallel for each package
  async.map packages, addIdsToPackage, (err, results)->
    callback( null, results )

addIdsToPackage = (pack, callback)->
  setIdFn = (obj, idx)-> obj.id = idx
  async.auto {
    methods: (callback)->
      flatMethodList = _.chain( pack.methodSets ).pluck( 'methods' ).flatten().value()
      _.each( flatMethodList, setIdFn )
      callback( null, null )

    methodSets:(callback)-> _.each( pack.methodSets, setIdFn ); callback( null, null )
    types: (callback)-> _.each( pack.types, setIdFn ); callback( null, null )

    # copy the method set ids to the methods
    methodSetMethods: ['methods', 'methodSets', (callback)->
      for ms in pack.methodSets
        methodSetId = ms.id
        m.methodSet = methodSetId for m in ms.methods
      callback( null, null )
    ]

  }, (err, results)->
    callback( null, pack )

module.exports = addIdsToPackages
