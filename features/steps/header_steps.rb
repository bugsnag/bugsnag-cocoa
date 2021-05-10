# frozen_string_literal: true

# @!group Header steps

Then('the {word} {string} header is null') do |request_type, header_name|
  assert_nil(Maze::Server.list_for(request_type).current[:request][header_name],
             "The #{request_type} '#{header_name}' header should be null")
end
