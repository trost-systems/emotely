# frozen_string_literal: true

# Run from apps/mobile/app: bundle exec ruby fastlane/test/run.rb
#
# The answers the store-consoles skill types into the consoles: present,
# readable, and within the console's own limits, so a run never stops on a
# field the console refuses.
require "minitest/autorun"
require "yaml"

class ConsoleAnswersTest < Minitest::Test
  DIR = File.expand_path("../console", __dir__)

  def play
    YAML.safe_load_file(File.join(DIR, "play.yaml"), permitted_classes: [Date])
  end

  def test_play_answers_name_every_console_step
    %w[privacy_policy_url category contact production_countries app_access content_rating].each do |key|
      assert play.key?(key), "play.yaml lacks #{key}"
    end
  end

  def test_the_privacy_policy_is_the_apps_notice
    assert_equal "https://getemotely.com/app-privacy", play["privacy_policy_url"]
  end

  def test_sign_in_instructions_fit_plays_500_characters
    play["app_access"].each do |entry|
      text = File.read(File.join(DIR, entry.fetch("instructions_file")), encoding: "UTF-8").strip

      assert_operator text.length, :<=, 500, "#{entry["instructions_file"]} has #{text.length} characters"
    end
  end

  def test_no_password_is_kept_with_the_answers
    Dir.glob(File.join(DIR, "*")).each do |file|
      refute_match(/password\s*[:=]/i, File.read(file), "#{File.basename(file)} looks like it holds a password")
    end
  end
end
