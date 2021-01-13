require 'json'

###

def infer
  issue_count = 0
  JSON.parse(File.read('infer-out/report.json')).each do |result|
    case result['severity']
    when 'ERROR'
      fail(result['qualifier'], file: result['file'], line: result['line'])
    when 'WARNING'
      warn(result['qualifier'], file: result['file'], line: result['line'])
    end
    issue_count += 1
  end
  markdown("**[Infer](https://fbinfer.com)**: No issues found :tada:") if issue_count == 0
end

###

def framework_size
  def _(number) # Formats a number with thousands separated by ','
    number.to_s.reverse.scan(/.{1,3}/).join(',').reverse
  end

  # The .size_after and .size_before files must be created prior to running this Dangerfile.
  size_after = File.read('.size_after').to_i
  size_before = File.read('.size_before').to_i

  case true
  when size_after == size_before
    markdown("**`Bugsnag.framework`** binary size did not change - #{_(size_after)} bytes")
  when size_after < size_before
    markdown("**`Bugsnag.framework`** binary size decreased by #{_(size_before - size_after)} bytes from #{_(size_before)} to #{_(size_after)} :tada:")
  when size_after > size_before
    markdown("**`Bugsnag.framework`** binary size increased by #{_(size_after - size_before)} bytes from #{_(size_before)} to #{_(size_after)}")
  end
end

###

infer()
framework_size()
