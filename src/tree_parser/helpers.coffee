
assert_token_group = ( token, group_name )->
  if token._group != group_name
    throw new Error("expected #{group_name}, got #{token._group} (#{token._type})")

module.exports =
    assert_token_group: assert_token_group
