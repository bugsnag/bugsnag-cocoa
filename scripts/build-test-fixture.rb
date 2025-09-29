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

run_command 'bundle install'
run_command 'make test-fixtures'

puts 'Uploading IPA to BrowserStack'
run_command 'bundle exec upload-app --farm=bs --app=./features/fixtures/ios/output/iOSTestApp_Release.ipa --app-id-file=./features/fixtures/ios/output/ipa_url_bs_release.txt'


