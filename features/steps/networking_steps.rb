Then(/^I wait for a request$/) do
  step "I wait for 1 request"
end

Then(/^I wait for (\d+) requests?$/) do |request_count|
  max_attempts = 300
  attempts = 0
  received = false
  until (attempts >= max_attempts) || received
    attempts += 1
    received = (stored_requests.size == request_count)
    sleep 0.1
  end
  raise "Requests not received in 30s (received #{stored_requests.size})" unless received
  # Wait an extra second to ensure there are no further requests
  sleep 1
  assert_equal(request_count, stored_requests.size, "#{stored_requests.size} requests received")
end
