# frozen_string_literal: true

# vim: set ft=ruby

def framework_size
  def _(number) # Formats a number with thousands separated by ','
    number.to_s.reverse.scan(/.{1,3}/).join(',').reverse
  end

  old_binary = 'build.base/Release-iphoneos/Bugsnag.framework/Bugsnag'
  new_binary = 'build/Release-iphoneos/Bugsnag.framework/Bugsnag'

  size_after = File.size(new_binary)
  size_before = File.size(old_binary)

  case true
  when size_after == size_before
    markdown("**`Bugsnag.framework`** binary size did not change - #{_(size_after)} bytes")
  when size_after < size_before
    markdown("**`Bugsnag.framework`** binary size decreased by #{_(size_before - size_after)} bytes from #{_(size_before)} to #{_(size_after)} :tada:")
  when size_after > size_before
    markdown("**`Bugsnag.framework`** binary size increased by #{_(size_after - size_before)} bytes from #{_(size_before)} to #{_(size_after)}")
  end

  markdown <<~MARKDOWN
    ```
    #{`bloaty #{new_binary} -- #{old_binary}`.chomp}
    ```
  MARKDOWN
end

if defined?(github) && github.branch_for_base == 'master' && !github.branch_for_head.start_with?('release-')
  failure 'Only release PRs should target the master branch'
end

begin
  diff = git.diff_for_file Dir['Bugsnag/**/BSGRunContext.h'][0]
  if diff && diff.patch !~ /BSGRUNCONTEXT_VERSION/
    warn 'This PR modifies `BSGRunContext.h` but does not change `BSGRUNCONTEXT_VERSION`'
  end
end

framework_size
