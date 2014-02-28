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
  @key = "TYPE"
  @fields = [ "name", "as"]
  @tags = [ "type" ]

class Alias extends node.Node
  @key = "ALIAS"
  @fields = [ "original" ]

class Fields extends node.Node
  @key = "FIELDS"
  @fields = ["fields"]

class Var extends node.Node
  @key = "VAR"
  @fields = ["type", "name"]

node.register CompilationUnit, Package, Identifier, Contents, TypeDecl, Alias, Struct, Fields, Var

node.make_type "CLASS", ["layout"]
