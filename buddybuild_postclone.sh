brew cask install oclint
xcodebuild -project iOS/Bugsnag.xcodeproj -scheme Bugsnag \
    COMPILER_INDEX_STORE_ENABLE=NO | tee xcodebuild.log | xcpretty -r json-compilation-database -o compile_commands.json
# Running analysis
oclint-json-compilation-database
