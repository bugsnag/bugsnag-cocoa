# A collection of steps that could be added to Maze Runner

Then('the event {string} equals one of:') do |field, possible_values|
  value = Maze::Helper.read_key_path(Maze::Server.errors.current[:body], "events.0.#{field}")
  assert_includes(possible_values.raw.flatten, value)
end

Then('the event {string} is within {int} seconds of the current timestamp') do |field, threshold_secs|
  value = Maze::Helper.read_key_path(Maze::Server.errors.current[:body], "events.0.#{field}")
  assert_not_nil(value, 'Expected a timestamp')
  now_secs = Time.now.to_i
  then_secs = Time.parse(value).to_i
  delta = now_secs - then_secs
  assert_true(delta.abs < threshold_secs, "Expected current timestamp, but received #{value}")
end

Then('the event {string} is between {float} and {float}') do |field, lower, upper|
  value = Maze::Helper.read_key_path(Maze::Server.errors.current[:body], "events.0.#{field}")
  assert_not_nil(value, 'Expected a value')
  assert_true(lower <= value && value <= upper, "Expected a value between #{lower} and #{upper}, but received #{value}")
end

Then('the event {string} is between {int} and {int}') do |field, lower, upper|
  value = Maze::Helper.read_key_path(Maze::Server.errors.current[:body], "events.0.#{field}")
  assert_not_nil(value, 'Expected a value')
  assert_true(lower <= value && value <= upper, "Expected a value between #{lower} and #{upper}, but received #{value}")
end

Then('the event {string} is less than the event {string}') do |field1, field2|
  value1 = Maze::Helper.read_key_path(Maze::Server.errors.current[:body], "events.0.#{field1}")
  assert_not_nil(value1, 'Expected a value')
  value2 = Maze::Helper.read_key_path(Maze::Server.errors.current[:body], "events.0.#{field2}")
  assert_not_nil(value2, 'Expected a value')
  assert_true(value1 < value2, "Expected value to be less than #{value2}, but received #{value1}")
end

Then('the event breadcrumbs contain {string} with type {string}') do |string, type|
  crumbs = Maze::Helper.read_key_path(find_request(0)[:body], 'events.0.breadcrumbs')
  assert_not_equal(0, crumbs.length, 'There are no breadcrumbs on this event')
  match = crumbs.detect do |crumb|
    crumb['name'] == string && crumb['type'] == type
  end
  assert_not_nil(match, 'No crumb matches the provided message and type')
end

Then('the event breadcrumbs contain {string}') do |string|
  crumbs = Maze::Helper.read_key_path(Maze::Server.errors.current[:body], 'events.0.breadcrumbs')
  assert_not_equal(0, crumbs.length, 'There are no breadcrumbs on this event')
  match = crumbs.detect do |crumb|
    crumb['name'] == string
  end
  assert_not_nil(match, 'No crumb matches the provided message')
end

Then('the stack trace is an array with {int} stack frames') do |expected_length|
  stack_trace = Maze::Helper.read_key_path(Maze::Server.errors.current[:body], 'events.0.exceptions.0.stacktrace')
  assert_equal(expected_length, stack_trace.length)
end

Then('the {string} of stack frame {int} equals one of:') do |key, num, possible_values|
  field = "events.0.exceptions.0.stacktrace.#{num}.#{key}"
  value = Maze::Helper.read_key_path(Maze::Server.errors.current[:body], field)
  assert_includes(possible_values.raw.flatten, value)
end

Then('the stacktrace contains methods:') do |table|
  stack_trace = Maze::Helper.read_key_path(Maze::Server.errors.current[:body], 'events.0.exceptions.0.stacktrace')
  expected = table.raw.flatten
  actual = stack_trace.map { |s| s['method'] }
  contains = actual.each_cons(expected.length).to_a.include? expected
  assert_true(contains, "Stacktrace methods #{actual} did not contain #{expected}")
end
