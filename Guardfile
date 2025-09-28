# Guard Configuration for Curated.www
# Real-time quality monitoring and testing
# Run with: bundle exec guard

# More info at https://github.com/guard/guard#readme

# Clear terminal on start
clearing :on

# Define notification settings
notification :terminal_notifier, app_name: "Curated.www Quality Guard" if `uname` =~ /Darwin/
notification :libnotify if `uname` =~ /Linux/

# Global ignore patterns
ignore %r{^coverage/}, %r{^log/}, %r{^tmp/}, %r{^vendor/}, %r{node_modules/}

# RSpec Guard - Run tests automatically
group :red_green_refactor, halt_on_fail: true do
  guard :rspec, cmd: "bundle exec rspec", notification: true do
    require "guard/rspec/dsl"
    dsl = Guard::RSpec::Dsl.new(self)

    # Feel free to open issues for suggestions and improvements

    # RSpec files
    rspec = dsl.rspec
    watch(rspec.spec_helper) { rspec.spec_dir }
    watch(rspec.spec_support) { rspec.spec_dir }
    watch(rspec.spec_files)

    # Ruby files
    ruby = dsl.ruby
    dsl.watch_spec_files_for(ruby.lib_files)

    # Rails files
    rails = dsl.rails(view_extensions: %w[erb haml slim])
    dsl.watch_spec_files_for(rails.app_files)
    dsl.watch_spec_files_for(rails.views)

    watch(rails.controllers) do |m|
      [
        rspec.spec.call("routing/#{m[1]}_routing"),
        rspec.spec.call("controllers/#{m[1]}_controller"),
        rspec.spec.call("acceptance/#{m[1]}")
      ]
    end

    # Rails config changes
    watch(rails.spec_helper)     { rspec.spec_dir }
    watch(rails.routes)          { "#{rspec.spec_dir}/routing" }
    watch(rails.app_controller)  { "#{rspec.spec_dir}/controllers" }

    # Capybara features specs
    watch(rails.view_dirs)     { |m| rspec.spec.call("features/#{m[1]}") }
    watch(rails.layouts)       { |m| rspec.spec.call("features/#{m[1]}") }

    # Turnip features and steps
    watch(%r{^spec/acceptance/(.+)\.feature$})
    watch(%r{^spec/acceptance/steps/(.+)_steps\.rb$}) do |m|
      Dir[File.join("**/#{m[1]}.feature")][0] || "spec/acceptance"
    end
  end
end

# RuboCop Guard - Run style checks automatically
guard :rubocop, all_on_start: false, keep_failed: false, notification: true do
  watch(/.+\.rb$/)
  watch(%r{(?:.+/)?\.rubocop(?:_todo)?\.yml$}) { |m| File.dirname(m[0]) }
end

# Brakeman Guard - Run security checks automatically
guard :brakeman,
      run_on_start: true,
      quiet: true,
      chat_notifications: true,
      output_files: [ 'tmp/brakeman.html' ],
      notifications: true do
  watch(%r{^app/.+\.(rb|erb)$})
  watch(%r{^app/controllers/.+\.rb$})
  watch(%r{^app/models/.+\.rb$})
  watch(%r{^app/helpers/.+\.rb$})
  watch(%r{^app/views/.+\.erb$})
  watch(%r{^app/mailers/.+\.rb$})
  watch(%r{^config/.+\.rb$})
  watch(%r{^lib/.+\.rb$})
  watch('Gemfile')
  watch('Gemfile.lock')
end

# Custom quality guard
guard :shell, all_on_start: true do
  # Custom quality checks including anti-pattern detection
  watch(%r{^app/(.+)\.rb$}) do |m|
    puts "🔍 Running targeted quality checks for #{m[0]}"
    system("./script/dev/quality-check-file #{m[0]}")
    system("./script/dev/anti-pattern-detection #{m[0]}")
  end

  # Watch for view changes
  watch(%r{^app/views/.+\.erb$}) do |m|
    puts "🔍 Running i18n check for #{m[0]}"
    system("./script/dev/i18n-check-file #{m[0]}")
    system("./script/dev/anti-pattern-detection #{m[0]}")
  end

  # Watch for migration changes
  watch(%r{^db/migrate/.+\.rb$}) do |m|
    puts "🔍 Running migration safety check for #{m[0]}"
    system("./script/dev/migration-check #{m[0]}")
  end

  # Watch for route changes
  watch(%r{^config/routes\.rb$}) do |m|
    puts "🔍 Running route testing validation"
    system("./script/dev/route-test-check")
  end

  # Watch for test changes - prevent test shortcuts
  watch(%r{^spec/.+_spec\.rb$}) do |m|
    puts "🔍 Running anti-pattern check for test #{m[0]}"
    system("./script/dev/anti-pattern-detection #{m[0]}")
  end

  # Watch for dependency changes
  watch(%r{^Gemfile$}) do |m|
    puts "🔍 Running dependency security check"
    system("bundle audit --update")
  end
end

# File system monitoring options
# Use polling on systems where file system events are not reliable
# guard :rspec, cmd: "bundle exec rspec --color", force_polling: true do
