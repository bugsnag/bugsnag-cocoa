# frozen_string_literal: true

# A collection of steps that could be added to Maze Runner

When('I ignore invalid {word}') do |type|
  Maze.config.captured_invalid_requests.delete(type.to_sym)
end

def platform_matches?(platform)
  Maze::Helper.get_current_platform == platform.downcase
end

Then(/^on (iOS|macOS|watchOS), (.+)/) do |platform, step_text|
  step(step_text) if platform_matches?(platform)
end

Then(/^on (iOS|macOS) ([0-9.]+) and later, (.+)/) do |platform, version, step_text|
  next unless platform_matches?(platform)
  raise 'Maze.config.os_version is not defined' if Maze.config.os_version.nil?
  step(step_text) if Gem::Version.new(Maze.config.os_version) >= Gem::Version.new(version)
end

Then(/^on !(iOS|macOS|watchOS), (.+)/) do |platform, step_text|
  step(step_text) unless platform_matches?(platform)
end

Then('the event {string} equals one of:') do |field, possible_values|
  value = Maze::Helper.read_key_path(Maze::Server.errors.current[:body], "events.0.#{field}")
  Maze.check.includes(possible_values.raw.flatten, value)
end

Then('the event {string} is a boolean') do |field|
  value = Maze::Helper.read_key_path(Maze::Server.errors.current[:body], "events.0.#{field}")
  Maze.check.include [true, false], value
end

Then('the event {string} is a non-empty array') do |field|
  value = Maze::Helper.read_key_path(Maze::Server.errors.current[:body], "events.0.#{field}")
  Maze.check.kind_of Array, value
  Maze.check.true(value.length.positive?, "the field '#{field}' must be a non-empty array")
end

Then('the event {string} is a number') do |field|
  value = Maze::Helper.read_key_path(Maze::Server.errors.current[:body], "events.0.#{field}")
  Maze.check.kind_of Numeric, value
end

Then('the event {string} is an array with {int} elements') do |field, count|
  value = Maze::Helper.read_key_path(Maze::Server.errors.current[:body], "events.0.#{field}")
  Maze.check.kind_of Array, value
  Maze.check.equal(count, value.length)
end

Then('the event {string} is an integer') do |field|
  value = Maze::Helper.read_key_path(Maze::Server.errors.current[:body], "events.0.#{field}")
  Maze.check.kind_of Integer, value
end

Then('the event {string} is within {int} seconds of the current timestamp') do |field, threshold_secs|
  value = Maze::Helper.read_key_path(Maze::Server.errors.current[:body], "events.0.#{field}")
  Maze.check.not_nil(value, 'Expected a timestamp')
  now_secs = Time.now.to_i
  then_secs = Time.parse(value).to_i
  delta = now_secs - then_secs
  Maze.check.true(delta.abs < threshold_secs, "Expected current timestamp, but received #{value}")
end

Then('the event {string} is between {float} and {float}') do |field, lower, upper|
  value = Maze::Helper.read_key_path(Maze::Server.errors.current[:body], "events.0.#{field}")
  Maze.check.not_nil(value, 'Expected a value')
  Maze.check.true(lower <= value && value <= upper,
                  "Expected a value between #{lower} and #{upper}, but received #{value}")
end

Then('the event {string} is between {int} and {int}') do |field, lower, upper|
  value = Maze::Helper.read_key_path(Maze::Server.errors.current[:body], "events.0.#{field}")
  Maze.check.not_nil(value, 'Expected a value')
  Maze.check.true(lower <= value && value <= upper,
                  "Expected a value between #{lower} and #{upper}, but received #{value}")
end

Then('the event {string} is less than the event {string}') do |field1, field2|
  value1 = Maze::Helper.read_key_path(Maze::Server.errors.current[:body], "events.0.#{field1}")
  Maze.check.not_nil(value1, 'Expected a value')
  value2 = Maze::Helper.read_key_path(Maze::Server.errors.current[:body], "events.0.#{field2}")
  Maze.check.not_nil(value2, 'Expected a value')
  Maze.check.true(value1 < value2, "Expected value to be less than #{value2}, but received #{value1}")
end

Then('the event breadcrumbs contain {string} with type {string}') do |string, type|
  crumbs = Maze::Helper.read_key_path(find_request(0)[:body], 'events.0.breadcrumbs')
  Maze.check.not_equal(0, crumbs.length, 'There are no breadcrumbs on this event')
  match = crumbs.detect do |crumb|
    crumb['name'] == string && crumb['type'] == type
  end
  Maze.check.not_nil(match, 'No crumb matches the provided message and type')
end

Then('the event breadcrumbs contain {string}') do |string|
  crumbs = Maze::Helper.read_key_path(Maze::Server.errors.current[:body], 'events.0.breadcrumbs')
  Maze.check.not_equal(0, crumbs.length, 'There are no breadcrumbs on this event')
  match = crumbs.detect do |crumb|
    crumb['name'] == string
  end
  Maze.check.not_nil(match, 'No crumb matches the provided message')
end

Then('the stack trace is an array with {int} stack frames') do |expected_length|
  stack_trace = Maze::Helper.read_key_path(Maze::Server.errors.current[:body], 'events.0.exceptions.0.stacktrace')
  Maze.check.equal(expected_length, stack_trace.length)
end

Then('the {string} of stack frame {int} equals one of:') do |key, num, possible_values|
  field = "events.0.exceptions.0.stacktrace.#{num}.#{key}"
  value = Maze::Helper.read_key_path(Maze::Server.errors.current[:body], field)
  Maze.check.includes(possible_values.raw.flatten, value)
end

Then('the stacktrace contains methods:') do |table|
  stack_trace = Maze::Helper.read_key_path(Maze::Server.errors.current[:body], 'events.0.exceptions.0.stacktrace')
  expected = table.raw.flatten
  actual = stack_trace.map { |s| s['method'] }
  contains = actual.each_cons(expected.length).to_a.include? expected
  Maze.check.true(contains, "Stacktrace methods #{actual} did not contain #{expected}")
end

Then('the stacktrace contains one of the following methods:') do |possible_values|
  field = "events.0.exceptions.0.stacktrace"
  expected = possible_values.raw.flatten
  stacktrace = Maze::Helper.read_key_path(Maze::Server.errors.current[:body], field)
  methods = stacktrace.map { |frame| frame["method"] }
  contains = expected.any? { |expected_method| methods.include?(expected_method) }
  Maze.check.true(contains, "Stacktrace methods #{methods} did not contain #{expected}")
end

Then('the received sessions match:') do |table|
  requests = Maze::Server.sessions.remaining
  match_count = 0

  # iterate through each row in the table. exactly 1 request should match each row.
  table.hashes.each do |row|
    requests.each do |request|
      sessions = request.dig(:body, 'sessions')
      Maze.check.equal(1, sessions.length, 'Expected exactly one session per request')
      match_count += 1 if Maze::Assertions::RequestSetAssertions.request_matches_row(sessions[0], row)
    end
  end
  Maze.check.equal(requests.size, match_count, 'Unexpected number of requests matched the received payloads')
end
