# frozen_string_literal: true

# Checks that every feature flag in the event is well-formed and internally consistent: each entry
# is an object containing only "featureFlag" and "variant" strings, names are unique, and each
# variant starts with the flag's own name followed by the separator (e.g. "t1-f03" => "t1-f03:42").
Then('every feature flag in the event has a variant starting with its name and {string}') do |separator|
  flags = Maze::Helper.read_key_path(Maze::Server.errors.current[:body], 'events.0.featureFlags')
  Maze.check.true(flags.is_a?(Array), "Expected featureFlags to be an array, was #{flags.inspect}")
  flags.each_with_index do |flag, i|
    Maze.check.true(flag.is_a?(Hash), "featureFlags.#{i} is not an object: #{flag.inspect}")
    Maze.check.true((flag.keys - %w[featureFlag variant]).empty?, "featureFlags.#{i} has unexpected keys: #{flag.inspect}")
    name = flag['featureFlag']
    variant = flag['variant']
    Maze.check.true(name.is_a?(String) && !name.empty?, "featureFlags.#{i} has an invalid name: #{flag.inspect}")
    Maze.check.true(variant.is_a?(String) && variant.start_with?("#{name}#{separator}"),
                    "featureFlags.#{i} has a variant inconsistent with its name: #{flag.inspect}")
  end
  names = flags.map { |flag| flag['featureFlag'] }
  duplicates = names.select { |name| names.count(name) > 1 }.uniq
  Maze.check.true(duplicates.empty?, "Duplicate feature flags: #{duplicates}")
end
