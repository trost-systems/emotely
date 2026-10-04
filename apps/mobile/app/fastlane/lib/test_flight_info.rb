# frozen_string_literal: true

require_relative "store_paths"
require_relative "beta_notes"

# What TestFlight shows a tester, per language, as pilot's options for both
# iOS lanes (fastlane 2.240.1, pilot/lib/pilot/build_manager.rb,
# BuildManager#update_beta_app_meta):
#
# - `localized_app_info`: the app's Test Information, one folder per
#   language in fastlane/testflight (description, feedback_email,
#   marketing_url, privacy_policy_url; trailing whitespace stripped). pilot
#   updates the language's betaAppLocalization or creates it.
# - `localized_build_info`: the build's "What to Test", the beta note of
#   each language (fastlane/lib/beta_notes.rb), for every language the build
#   has. `default` is the English note, for a language with no note of its
#   own. It takes precedence over `changelog`, which wrote the English note
#   into every language, so German testers read English.
# - `changelog`: still the English note. pilot's upload with
#   skip_waiting_for_build_processing returns before it sets any of this
#   unless `changelog` is set (BuildManager#upload), and a distribution to
#   external testers requires one or the other.
module TestFlightInfo
  DIR = StorePaths::TESTFLIGHT_DIR
  FIELDS = %w[description feedback_email marketing_url privacy_policy_url].freeze

  def self.locales
    Dir.children(DIR).select { |entry| File.directory?(File.join(DIR, entry)) }.sort
  end

  # { "en-US" => { description: "…", feedback_email: "…", … }, … }
  def self.app_info
    locales.to_h do |locale|
      fields = FIELDS.to_h do |field|
        [field.to_sym, File.read(File.join(DIR, locale, "#{field}.txt"), encoding: "UTF-8").strip]
      end
      [locale, fields]
    end
  end

  def self.build_info
    notes = locales.to_h { |locale| [locale, { whats_new: BetaNotes.text(locale) }] }
    { "default" => { whats_new: BetaNotes.text("en-US") } }.merge(notes)
  end

  def self.pilot_options
    {
      changelog: BetaNotes.text("en-US"),
      localized_app_info: app_info,
      localized_build_info: build_info
    }
  end
end
