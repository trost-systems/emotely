# frozen_string_literal: true

# Run from apps/mobile/app: bundle exec ruby fastlane/test/run.rb
#
# fastlane runs lane code inside fastlane/ but actions (deliver, supply) in
# its parent, so a path relative to either is wrong for the other: the first
# store-listings run on main (37117064456) uploaded no listing because
# metadata_path was "./metadata". Every path a lane hands on is absolute.
require "minitest/autorun"
require_relative "../lib/store_paths"

class StorePathsTest < Minitest::Test
  FASTLANE = File.expand_path("..", __dir__)

  def test_every_path_is_absolute_wherever_it_is_read_from
    Dir.chdir("/") do
      [StorePaths::APP_DIR, StorePaths::METADATA_DIR, StorePaths::APP_REVIEW_DIR, StorePaths::TESTFLIGHT_DIR,
       StorePaths::DATA_SAFETY_CSV].each do |path|
        assert path.start_with?("/"), "#{path} is relative"
      end
    end
  end

  def test_the_paths_are_the_folders_the_repository_keeps
    assert_equal File.expand_path("..", FASTLANE), StorePaths::APP_DIR
    assert_equal File.join(FASTLANE, "metadata"), StorePaths::METADATA_DIR
    assert File.directory?(File.join(StorePaths::METADATA_DIR, "android")), "no Play listing under #{StorePaths::METADATA_DIR}"
    assert File.directory?(StorePaths::APP_REVIEW_DIR), "no App Review folder at #{StorePaths::APP_REVIEW_DIR}"
    assert File.directory?(StorePaths::TESTFLIGHT_DIR), "no TestFlight folder at #{StorePaths::TESTFLIGHT_DIR}"
    assert_equal File.join(FASTLANE, "data_safety.csv"), StorePaths::DATA_SAFETY_CSV
  end
end
