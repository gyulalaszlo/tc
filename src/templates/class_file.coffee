_ = require 'underscore'

_.extend exports,
  CLASS: _.template "%{layout}"
  FIELDS: _.template "%{fields}"
  ARGS: _.template "<%= to_c() %>"
  VAR: _.template "  <%= type.name %> <%= name %>;\n"

  METHODS: _.template "<%= access %>:\n%{body}"
  METHOD: _.template "  <%= real_name() %>%{func}"
  FUNC: _.template "(%{args}) { }\n"
