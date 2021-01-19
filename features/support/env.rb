# Set this explicitly
$api_key = "12312312312312312312312312312312"

AfterConfiguration do |_config|
  Maze.config.receive_no_requests_wait = 15
end
