Pod::Spec.new do |s|
  s.name             = 'BugsnagNetworkBreadcrumbs'
  s.version          = '6.11.0'
  s.summary          = 'Bugsnag network breadcrumbs plugin.'

  s.description      = <<-DESC
Adds support to Bugsnag for capturing network operations as breadcrumbs.
                       DESC

  s.homepage         = 'https://bugsnag.com'
  s.license          = 'MIT'
  s.authors          = { 'Bugsnag': 'notifiers@bugsnag.com' }

  s.source           = {
    :git => 'https://github.com/bugsnag/bugsnag-cocoa.git',
    :tag => 'v' + s.version.to_s
  }

  s.ios.deployment_target = '9.3'
  s.osx.deployment_target = '10.11'
  s.tvos.deployment_target = '9.2'

  s.cocoapods_version = '>= 1.4.0'

  s.dependency 'Bugsnag', '~> ' + s.version.to_s

  s.source_files = "BugsnagNetworkBreadcrumbs/{**/,}*.{m,h,mm,c}"
  s.requires_arc = true
  s.prefix_header_file = false
  s.public_header_files = "BugsnagNetworkBreadcrumbs/include/Bugsnag/*.h"
end
