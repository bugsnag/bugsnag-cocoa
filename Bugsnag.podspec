Pod::Installer::UserProjectIntegrator::TargetIntegrator.class_eval do
  unless method_defined?(:integrate_with_bugsnag!)

    BUGSNAG_PHASE_NAME = "Upload Bugsnag dSYM"
    BUGSNAG_PHASE_SCRIPT = <<'RUBY'

if ENV["EFFECTIVE_PLATFORM_NAME"] == "-iphonesimulator" ||
   ENV["DEBUG_INFORMATION_FORMAT"] != "dwarf-with-dsym"
  exit
end

fork do
  Process.setsid
  STDIN.reopen("/dev/null")
  STDOUT.reopen("/dev/null", "a")
  STDERR.reopen("/dev/null", "a")

  require 'shellwords'

  Dir["#{ENV["DWARF_DSYM_FOLDER_PATH"]}/#{ENV["DWARF_DSYM_FILE_NAME"]}/Contents/Resources/DWARF/*"].each do |dsym|
    puts dsym
    system("curl -F dsym=@#{Shellwords.escape(dsym)} -F projectRoot=#{Shellwords.escape(dsym)} https://upload.bugsnag.com/")
  end
end
RUBY

    def integrate_with_bugsnag!
      integrate_without_bugsnag!
      return if bugsnag_native_targets.empty?
      UI.section("Integrating with Bugsnag") do
        add_bugsnag_upload_script_phase
        user_project.save
      end
    end

    alias integrate_without_bugsnag! integrate!
    alias integrate! integrate_with_bugsnag!

    def add_bugsnag_upload_script_phase
      bugsnag_native_targets.each do |native_target|
        phase = native_target.shell_script_build_phases.select{ |bp| bp.name == BUGSNAG_PHASE_NAME }.first ||
                native_target.new_shell_script_build_phase(BUGSNAG_PHASE_NAME)

        phase.shell_path = "/usr/bin/ruby"
        phase.shell_script = BUGSNAG_PHASE_SCRIPT
        phase.show_env_vars_in_log = '0'
      end
    end

    def bugsnag_native_targets
      @bugsnag_native_targets ||=(
        target_uuids = target.user_target_uuids
        target_uuids.map do |uuid|
          native_target = user_project.objects_by_uuid[uuid]
          unless native_target
            raise Informative, "[Bug] Unable to find the target with " \
              "the `#{uuid}` UUID for the `#{target}` integration library"
          end
          native_target
        end
      )
    end
  end
end

Pod::Spec.new do |s|
  s.name         = "Bugsnag"
  s.version      = "3.0.0"
  s.summary      = "iOS notifier for SDK for bugsnag.com"
  s.homepage     = "https://bugsnag.com"
  s.license      = 'MIT'
  s.author       = { "Bugsnag" => "notifiers@bugsnag.com" }
  s.source       = { :git => "https://github.com/bugsnag/bugsnag-objective-c.git", :tag => "3.0.0" }
  s.platform     = :ios, '5.0'
  s.source_files = ['bugsnag/*.{h,m}']
  s.requires_arc = true
  s.dependency "Reachability"

  s.ios.source_files = "bugsnag/iOS/*.{h,m}"
end

