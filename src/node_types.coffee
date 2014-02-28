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
  is_constructor_or_destructor: ->
    return true if @name.text in ['Constructor', 'Destructor']
    false
  real_name: ->
    return switch @name.text
      # constructors and destructors reference their parent method
      # set for naming
      when "Constructor" then @parent.name
      when "Destructor" then "~#{@parent.name}"
      # otherwise its a normal method
      else @name.text

  return_type: ->
    return "" if @is_constructor_or_destructor()
    return "void" if @func.ret.list.length == 0
    (l.toString() for l in @func.ret.list ).join(', ')

node.make_type "FUNC", ["args", "body", "ret"]
node.make_type "ARGS", ["all"],
  to_c: ->
    children = (child.to_c() for child in @all)
    #console.log @children
    children.join(', ')

node.make_type "ARG", ["decl"],
  to_c: -> @decl.to_c()
node.make_type "TYPE", ["name"]

node.make_type "TYPELIST", ["list"],
  to_func_ret_c: ->
    console.log @list
    (l.toString() for l in @list ).join(', ')

