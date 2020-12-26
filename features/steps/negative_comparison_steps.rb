Then("the payload field {string} does not equal {string}") do |field_path, string_value|
  payload_value = read_key_path(Server.errors.current[:body], field_path)
  result = value_compare(payload_value, string_value)
  assert_false(result.equal?, "Value: #{string_value} equals payload element at: #{field_path}")
end

Then("the session {string} does not equal {string}") do |field_path, string_value|
  step "the payload field \"session.0.#{field_path}\" does not equal \"#{string_value}\""
end
