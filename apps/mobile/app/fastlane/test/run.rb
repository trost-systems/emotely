# frozen_string_literal: true

# Runs every test of the Fastfile's helpers (fastlane/lib), from
# apps/mobile/app: bundle exec ruby fastlane/test/run.rb
Dir.glob(File.join(__dir__, "*_test.rb")).sort.each { |test| require test }
