# frozen_string_literal: true

# Run from apps/mobile/app: bundle exec ruby fastlane/test/run.rb
#
# What TestFlight shows a tester, per language: the app's Test Information
# (description, feedback email, marketing and privacy URLs) and each build's
# "What to Test". pilot's plain `changelog` writes the English note into
# every language a build has, so German testers read English; the lanes pass
# the repository's text per language. The tests run pilot's own code with the
# lanes' options against a stand-in for App Store Connect.
require "minitest/autorun"
require "fastlane"
require "pilot"
require_relative "../lib/test_flight_info"
require_relative "../lib/beta_notes"

class TestFlightInfoTest < Minitest::Test
  Localization = Struct.new(:id, :locale)

  # App Store Connect's side: the localizations that exist, and every write.
  class FakeConnect
    attr_reader :writes

    def initialize
      @writes = []
    end

    def install
      api = Spaceship::ConnectAPI
      writes = @writes
      @originals = %i[patch_beta_app_localizations post_beta_app_localizations
                      patch_beta_build_localizations post_beta_build_localizations].to_h do |name|
        original = api.method(name)
        api.define_singleton_method(name) { |**args| writes << [name, args] }
        [name, original]
      end
    end

    def uninstall
      @originals&.each { |name, original| Spaceship::ConnectAPI.define_singleton_method(name, original) }
    end
  end

  def setup
    @connect = FakeConnect.new
    @connect.install
  end

  def teardown
    @connect.uninstall
  end

  # pilot sets a build's Test Information as both lanes reach it: the
  # internal upload once the build appears, the beta distribution before it
  # submits. App Store Connect has an English app localization and, for the
  # build, the English and German ones it creates by itself.
  def update(app_locales: ["en-US"], build_locales: %w[en-US de-DE])
    app = Object.new
    app.define_singleton_method(:id) { "app-1" }
    app.define_singleton_method(:get_beta_app_localizations) { app_locales.map { |l| Localization.new("app-#{l}", l) } }
    build = Object.new
    build.define_singleton_method(:id) { "build-1" }
    build.define_singleton_method(:get_beta_build_localizations) { build_locales.map { |l| Localization.new("build-#{l}", l) } }

    manager = Pilot::BuildManager.new
    manager.define_singleton_method(:app) { app }
    capture_subprocess_io { manager.update_beta_app_meta(TestFlightInfo.pilot_options, build) }
  end

  def writes(name)
    @connect.writes.select { |call, _| call == name }.map(&:last)
  end

  def test_each_language_of_a_build_gets_its_own_beta_note
    update

    whats_new = writes(:patch_beta_build_localizations).to_h { |args| [args[:localization_id], args[:attributes][:whatsNew]] }
    assert_equal({ "build-en-US" => BetaNotes.text("en-US"), "build-de-DE" => BetaNotes.text("de-DE") }, whats_new)
  end

  def test_a_language_the_build_lacks_is_created_with_its_note
    update(build_locales: ["en-US"])

    created = writes(:post_beta_build_localizations)
    assert_equal [{ build_id: "build-1", attributes: { whatsNew: BetaNotes.text("de-DE"), locale: :"de-DE" } }], created
  end

  def test_the_apps_test_information_comes_from_the_repository_in_both_languages
    update

    english = writes(:patch_beta_app_localizations)
    german = writes(:post_beta_app_localizations)
    assert_equal [{
      localization_id: "app-en-US",
      attributes: {
        feedbackEmail: "hello@getemotely.com",
        marketingUrl: "https://getemotely.com",
        # The app's notice, not the site's /privacy (drifted until 2026-10-04).
        privacyPolicyUrl: "https://getemotely.com/app-privacy",
        description: description("en-US")
      }
    }], english
    assert_equal [{
      app_id: "app-1",
      attributes: {
        feedbackEmail: "hello@getemotely.com",
        marketingUrl: "https://getemotely.com/de",
        privacyPolicyUrl: "https://getemotely.com/de/app-privacy",
        description: description("de-DE"),
        locale: :"de-DE"
      }
    }], german
  end

  def description(locale)
    File.read(File.join(TestFlightInfo::DIR, locale, "description.txt"), encoding: "UTF-8").strip
  end

  def test_every_language_has_every_field_and_a_beta_note
    assert_equal %w[de-DE en-US], TestFlightInfo.locales
    TestFlightInfo.locales.each do |locale|
      TestFlightInfo::FIELDS.each do |field|
        assert File.file?(File.join(TestFlightInfo::DIR, locale, "#{field}.txt")), "#{locale} lacks #{field}.txt"
      end
      assert File.file?(BetaNotes.path(locale)), "#{locale} has no beta note"
    end
  end

  def test_the_descriptions_fit_app_store_connects_4000_characters
    %w[en-US de-DE].each do |locale|
      refute_empty description(locale), locale
      assert_operator description(locale).length, :<=, 4000, locale
    end
  end

  # pilot's upload with skip_waiting_for_build_processing returns before it
  # sets any Test Information unless `changelog` is set (Pilot::BuildManager
  # #upload), so the internal lane keeps passing it beside the localized info.
  def test_the_options_keep_the_changelog_that_makes_the_upload_set_them
    assert_equal BetaNotes.text("en-US"), TestFlightInfo.pilot_options[:changelog]
  end
end
