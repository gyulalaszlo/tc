node = require './node_base'

class CompilationUnit extends node.Node
  @key = "COMPILATION_UNIT"
  @fields = [ "package", "contents" ]

class Package extends node.Node
  @key = "PACKAGE"
  @fields = [ "name"]

class Identifier extends node.Node
  @key = "IDENTIFIER"
  @fields = [ "text"]

  toString: -> @text

class Contents extends node.Node
  @key = "CONTENTS"
  @fields = [ "declarations"]

class Struct extends node.Node
  @key = "STRUCT"
  @fields = [ "layout"]


class TypeDecl extends node.Node
  @key = "TYPEDECL"
  @fields = [ "name", "as"]
  @tags = [ "typedecl" ]

class Alias extends node.Node
  @key = "ALIAS"
  @fields = [ "original" ]

class Fields extends node.Node
  @key = "FIELDS"
  @fields = ["fields"]

class Var extends node.Node
  @key = "VAR"
  @fields = ["type", "name"]

  to_c: -> "#{@type.name} #{@name}"

node.register CompilationUnit, Package, Identifier, Contents, TypeDecl, Alias, Struct, Fields, Var

node.make_type "CLASS", ["layout"],
  tags: ["class"]
  name: -> @parent.name

node.make_type "METHODS", ["name", "access", "body"], tags: ["method_set"]
node.make_type "METHOD", ["name", "func"],
  real_name: ->
    return switch @name.text
      # constructors and destructors reference their parent method
      # set for naming
      when "Constructor" then @parent.name
      when "Destructor" then "~#{@parent.name}"
      # otherwise its a normal method
      else @name.text

node.make_type "FUNC", ["args", "body"]
node.make_type "ARGS", ["first", "more"],
  all: ->
    o = []
    o.push @first
    o.push @more...
    o
    #@first, @more
  to_c: -> 
    children = (child.to_c() for child in @all())
    #console.log @children
    children.join(', ')

node.make_type "ARG", ["decl"],
  to_c: -> @decl.to_c()
node.make_type "TYPE", ["name"]

