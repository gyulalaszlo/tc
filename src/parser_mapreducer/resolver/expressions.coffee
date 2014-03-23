# require the resolvers so they can register themselves
for k in [
  'assign'
  'this_access'
  'literal'
  'variable'
  'member'
]
  require "./expressions/#{k}"

expression = require './expressions/expression'
exports.resolve = expression

