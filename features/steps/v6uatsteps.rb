require 'date'

# Number

Then(/^the payload field "(.+)" is a number$/) do |field_path|
    value = read_key_path(Server.current_request[:body], field_path)
    assert_kind_of Numeric, value
end

# Float

Then(/^the payload field "(.+)" is a float$/) do |field_path|
    value = read_key_path(find_request(request_index)[:body], field_path)
    assert_kind_of Float, value
end

# Integer

Then(/^the payload field "(.+)" is an integer$/) do |field_path|
    value = read_key_path(Server.current_request[:body], field_path)
    assert_kind_of Integer, value
end

# Date

Then(/^the payload field "(.+)" is a date$/) do |field_path|
    value = read_key_path(Server.current_request[:body], field_path)
    date = Date.parse(value) rescue nil
    assert_kind_of Date, date
end

# UUID

Then(/^the payload field "(.+)" is a UUID$/) do |field_path|
    value = read_key_path(Server.current_request[:body], field_path)
    assert_not_nil(value, "Expected UUID, got nil for #{field_path}")
    match = /[A-F0-9-]{36}/.match(value).size() > 0
    assert_true(match, "Field #{field_path} is not a UUID, received #{value}")
end