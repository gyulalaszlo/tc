_ = require 'underscore'

_.extend exports,
  ALIAS: _.template "typedef <%= original.name %> <%= parent.name %>;"
  STRUCT: _.template "struct <%= parent.name %> %{layout};"
  CLASS: _.template "class <%= parent.name %>;"
  FIELDS: _.template "{\n%{fields}}"
  VAR: (a)->"  #{a.type.name} #{a.name};\n"
