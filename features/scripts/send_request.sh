#!/usr/bin/env ruby

require 'net/http'

# Sends a request to the mock server running on the port
# specified by the MOCK_API_PORT environment variable
http = Net::HTTP.new('localhost', ENV['MOCK_API_PORT'])
request = Net::HTTP::Post.new('/')
request['Content-Type'] = 'application/json'
request.body = '{"dessert":"' + ENV['menu_item'] + '"}'
http.request(request)
