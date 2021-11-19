#!/usr/bin/env ruby
require 'json'
require 'net/http'

# TODO: PLAT-7647 Remove once Maze Runner has support for --upload-app
def upload_app(username, access_key, app)
  upload_uri = 'https://api-cloud.browserstack.com/app-automate/upload'
  uri = URI(upload_uri)
  request = Net::HTTP::Post.new(uri)
  request.basic_auth(username, access_key)
  request.set_form({ 'file' => File.new(app, 'rb') }, 'multipart/form-data')

  puts "Uploading #{app} to #{upload_uri}"
  res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
    http.request(request)
  end

  begin
    body = res.body
    response = JSON.parse body
    raise "Upload failed due to error: #{response['error']}" if response.include?('error')
    raise "Upload failed, response did not include and app_url: #{res}" unless response.include?('app_url')
  rescue JSON::ParserError
    raise "Error: expected JSON response, received: #{body}"
  end

  response['app_url']
end

# Build the test fixture apps
`make test-fixtures`

# Upload the IPA to BrowserStack
url = upload_app ENV['BROWSER_STACK_USERNAME'], ENV['BROWSER_STACK_ACCESS_KEY'], 'features/fixtures/ios/output/iOSTestApp.ipa'
puts "BrowserStack URL is #{url}"
File.write('features/fixtures/ios/output/ipa_url.txt', url)
