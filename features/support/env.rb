# Set this explicitly
$api_key = "12312312312312312312312312312312"

AfterConfiguration do |_config|
  MazeRunner.config.receive_no_requests_wait = 15
  # TODO: Remove once the Bugsnag-Integrity header has been implemented
  MazeRunner.config.enforce_bugsnag_integrity = false
end
