# vim: set ft=ruby

require 'json'

###

def parse_infer_results(path)
  issue_count = 0
  JSON.parse(File.read(path)).each do |result|
    case result['severity']
    when 'ERROR'
      fail("[Infer] #{result['qualifier']}", file: result['file'], line: result['line'])
    when 'WARNING'
      warn("[Infer] #{result['qualifier']}", file: result['file'], line: result['line'])
    end
    issue_count += 1
  end
  markdown("**[Infer](https://fbinfer.com)**: No issues found :tada:") if issue_count == 0
end

###

def parse_oclint_results(path)
  issue_count = 0
  results = JSON.parse(File.read(path))
  results['violation'].each do |violation|
    file = violation['path'].sub("#{Dir.pwd}/", '')
    case violation['priority']
    when 1
      fail("[OCLint] #{violation['rule']}: #{violation['message']}", file: file, line: violation['startLine'])
    when 2, 3
      warn("[OCLint] #{violation['rule']}: #{violation['message']}", file: file, line: violation['startLine'])
    end
    issue_count += 1
  end
  markdown("**[OCLint](http://oclint.org)**: No issues found :tada:") if issue_count == 0
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

parse_infer_results('infer-out/report.json')

parse_oclint_results('oclint.json')

framework_size()
