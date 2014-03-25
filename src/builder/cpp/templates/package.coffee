_ = require 'underscore'
_s = require 'underscore.string'

typeHelpers = require './_type_helpers'


rule = "/* #{ _s.repeat '-', 40 } */"

module.exports = ( pack )->
  @line "#include \"#{ pack.name }_types.h\""

  @line "using namespace #{ pack.name };"

  # output the unpublished types first
  @indent "namespace {", "}", ->
    typeOrder =  typeHelpers.makeTypeDeclarationList( pack.types )
    notPublishedTypes = _.reject typeOrder, (id)-> pack.types[id].isPublished
    @mapHelper notPublishedTypes, typeHelpers.typeDeclaration, pack, pack.types


  # separator
  @lines '', rule, ''
  # then the method sets
  #
  @indent "namespace {", "}", ->

    groupedMethodSets = _.groupBy( pack.methodSets, 'target' )
    methodSets = for targetId, ms of groupedMethodSets
      methodSetIds = _.pluck ms, 'id'
      o = {
        methodSets: ms
        methods: _.filter( pack.methods, (m)-> m.methodSet in methodSetIds )
        target: if targetId == -1 then null else pack.types[targetId]
      }
      o

    for ms in methodSets
      targetName = if ms.target then ms.target.name else "<unbound>"
      @line ''
      @indent "/* Method set: #{ targetName } { */", "/* } */", ->
        @mapHelper ms.methods, typeHelpers.methodWithBody, pack.types
          #@line JSON.stringify( m.name )

