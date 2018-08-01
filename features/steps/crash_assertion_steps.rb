Then("The exception reflects malloc corruption occurred") do
  # Two different outcomes can arise from this scenario, either:
  # * Write will fail on non-writable memory
  # * malloc fails in NSLog
  body = find_request(0)[:body]
  exception = read_key_path(body, "events.0.exceptions.0")
  stacktrace = exception["stacktrace"]
  assert_true(stacktrace.length > 0, "The stacktrace must have more than 0 elements")

  case stacktrace.first["method"]
  when "__pthread_kill"
    assert_equal(exception["errorClass"], "SIGABRT")
    assert_equal(stacktrace[1]["method"], "abort")
  when "_nc_table_find_64"
    assert_equal(exception["errorClass"], "SIGSEGV")
    assert_equal(exception["message"], "Attempted to dereference null pointer.")

    frame = 1

    if stacktrace[frame]["method"] == "registration_node_find"
      frame = 2
    end

    assert_equal(stacktrace[frame]["method"], "notify_check")
    assert_equal(stacktrace[frame + 1]["method"], "notify_check_tz")
    assert_equal(stacktrace[frame + 2]["method"], "tzsetwall_basic")
    assert_equal(stacktrace[frame + 3]["method"], "localtime_r")
    assert_equal(stacktrace[frame + 4]["method"], "_populateBanner")
    assert_equal(stacktrace[frame + 5]["method"], "_CFLogvEx2Predicate")
    assert_equal(stacktrace[frame + 6]["method"], "_CFLogvEx3")
    assert_equal(stacktrace[frame + 7]["method"], "_NSLogv")
    assert_equal(stacktrace[frame + 8]["method"], "NSLog")
    assert_equal(stacktrace[frame + 9]["method"], "-[CorruptMallocScenario run]")
  else
    fail("The exception does not reflect malloc corruption")
  end
end
