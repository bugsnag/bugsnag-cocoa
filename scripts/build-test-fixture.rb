def run_command(command)
  puts command
  result = `#{command}`
  puts result
  unless $?.success?
    code = $?.exitstatus
    puts "Command failed with exit code #{code}"
    exit code
  end
end

def upload_dsyms(api_key, dest)
  puts "Uploading dsyms to #{dest}"
  run_command "bugsnag-cli upload dsym --api-key=#{api_key} --overwrite features/fixtures/ios/archive/iosTestApp_Release.xcarchive"
  run_command "bugsnag-cli upload dsym --api-key=#{api_key} --overwrite features/fixtures/macos/archive/macOSTestApp_Release.xcarchive"
end

run_command 'bundle install'
run_command 'make test-fixtures'

puts 'Uploading IPAs to BrowserStack and BitBar'
run_command 'bundle exec upload-app --farm=bb --app=./features/fixtures/ios/output/iOSTestApp_Release.ipa --app-id-file=./features/fixtures/ios/output/ipa_url_bb_release.txt'
run_command 'bundle exec upload-app --farm=bs --app=./features/fixtures/ios/output/iOSTestApp_Release.ipa --app-id-file=./features/fixtures/ios/output/ipa_url_bs_release.txt'
run_command 'bundle exec upload-app --farm=bb --app=./features/fixtures/ios/output/iOSTestApp_Debug.ipa --app-id-file=./features/fixtures/ios/output/ipa_url_bb_debug.txt'
run_command 'bundle exec upload-app --farm=bs --app=./features/fixtures/ios/output/iOSTestApp_Debug.ipa --app-id-file=./features/fixtures/ios/output/ipa_url_bs_debug.txt'

upload_dsyms(ENV['MAZE_REPEATER_API_KEY'], 'bugsnag.com') if ENV['MAZE_REPEATER_API_KEY']
upload_dsyms(ENV['MAZE_HUB_REPEATER_API_KEY'], 'Insight Hub') if ENV['MAZE_HUB_REPEATER_API_KEY']


