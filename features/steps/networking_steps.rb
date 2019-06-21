Then(/^I wait for a request$/) do
  step "I wait for 1 request"
end

Then(/^I wait for (\d+) requests?$/) do |request_count|
  max_attempts = 600
  attempts = 0
  received = false
  until (attempts >= max_attempts) || received
    attempts += 1
    received = (stored_requests.size == request_count)
    sleep 0.1
  end
  unless received
    raise "Requests not received in 60s (received #{stored_requests.size})"
  end

  # Wait an extra second to ensure there are no further requests
  sleep 1
  assert_equal(request_count, stored_requests.size, "#{stored_requests.size} requests received")
end
