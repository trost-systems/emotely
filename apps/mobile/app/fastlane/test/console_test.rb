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

  def test_app_privacy_details_use_only_ids_app_store_connect_knows
    require "json"
    require "spaceship"
    api = Spaceship::ConnectAPI
    usages = JSON.parse(File.read(File.join(DIR, "app_privacy_details.json")))

    refute_empty usages
    usages.each do |usage|
      assert_includes api::AppDataUsageCategory::ID.constants.map(&:to_s), usage.fetch("category")
      usage.fetch("purposes").each { |purpose| assert_includes api::AppDataUsagePurpose::ID.constants.map(&:to_s), purpose }
      usage.fetch("data_protections").each do |protection|
        assert_includes api::AppDataUsageDataProtection::ID.constants.map(&:to_s), protection
      end
    end
  end

  # What the app does with each data type, in Apple's purposes
  # (https://developer.apple.com/app-store/app-privacy-details/). The reasons
  # and the code behind them are in the release-app skill's
  # references/data-declarations.md; a change here is a change to what the
  # app collects or why, and the console follows it.
  PURPOSES = {
    # Supabase Auth: the account; the companion greets and addresses the user by it.
    "NAME" => %w[APP_FUNCTIONALITY PRODUCT_PERSONALIZATION],
    # Supabase Auth: sign-in. PostHog never receives it.
    "EMAIL_ADDRESS" => %w[APP_FUNCTIONALITY],
    # The journal (Supabase, the model) and, after Allow, survey free text (PostHog).
    "OTHER_USER_CONTENT" => %w[APP_FUNCTIONALITY ANALYTICS],
    # The account id (Supabase) and, after Allow, PostHog's person id (identify).
    "USER_ID" => %w[APP_FUNCTIONALITY ANALYTICS],
    # PostHog's random anonymous id, after Allow.
    "DEVICE_ID" => %w[ANALYTICS],
    # Screens, lifecycle and product events, after Allow.
    "PRODUCT_INTERACTION" => %w[ANALYTICS],
    # Uncaught Flutter errors, after Allow: fixed, never read as user behavior.
    "CRASH_DATA" => %w[APP_FUNCTIONALITY],
    # Handled failures and the device/app context on every event, after
    # Allow: fixed, and read in the product dashboards (session_failed in the
    # session-quality rate, $app_version cohorts, $is_emulator filtered out).
    "OTHER_DIAGNOSTIC_DATA" => %w[APP_FUNCTIONALITY ANALYTICS],
  }.freeze

  def test_app_privacy_details_declare_what_the_app_does
    require "json"
    usages = JSON.parse(File.read(File.join(DIR, "app_privacy_details.json")))
    declared = usages.to_h { |usage| [usage.fetch("category"), usage.fetch("purposes").sort] }

    assert_equal PURPOSES.transform_values(&:sort), declared
  end

  def test_everything_declared_is_linked_and_nothing_tracks
    require "json"
    JSON.parse(File.read(File.join(DIR, "app_privacy_details.json"))).each do |usage|
      assert_equal ["DATA_LINKED_TO_YOU"], usage.fetch("data_protections"), usage.fetch("category")
    end
  end

  def test_no_password_is_kept_with_the_answers
    Dir.glob(File.join(DIR, "*")).each do |file|
      refute_match(/password\s*[:=]/i, File.read(file), "#{File.basename(file)} looks like it holds a password")
    end
  end
end
