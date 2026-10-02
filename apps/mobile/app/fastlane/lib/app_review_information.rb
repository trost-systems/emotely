# frozen_string_literal: true

# The App Review information of the version in preparation (App Store Connect
# → version → App Review Information): contact, demo account and notes for
# Apple's reviewer.
#
# What may be public lives in fastlane/app_review/*.txt; the reviewer
# account's password and the contact phone come from secrets of the `release`
# environment and are never written to a file or a log. The lane PATCHes
# appStoreReviewDetails itself rather than handing this to deliver, because
# deliver's summary table prints the phone number
# (https://developer.apple.com/documentation/appstoreconnectapi/patch-v1-appstorereviewdetails-_id_).
module AppReviewInformation
  # A file or secret the review detail needs is absent.
  class Missing < StandardError; end

  # appStoreReviewDetails attribute => file in fastlane/app_review.
  FILES = {
    "contactFirstName" => "first_name.txt",
    "contactLastName" => "last_name.txt",
    "contactEmail" => "email_address.txt",
    "demoAccountName" => "demo_user.txt",
    "notes" => "notes.txt"
  }.freeze

  # appStoreReviewDetails attribute => secret (environment variable).
  SECRETS = {
    "contactPhone" => "APP_REVIEW_CONTACT_PHONE",
    "demoAccountPassword" => "APP_REVIEW_DEMO_PASSWORD"
  }.freeze

  # Apple's limit for the notes field.
  NOTES_LIMIT = 4000

  # The attributes to PATCH, from the files in `dir` and the secrets in `env`.
  # Raises Missing naming every absent file and secret, never a value.
  def self.attributes(dir, env: ENV)
    missing = FILES.values.reject { |file| File.exist?(File.join(dir, file)) }
    missing += SECRETS.values.select { |name| env[name].to_s.strip.empty? }
    raise Missing, "App Review information needs #{missing.join(", ")}" unless missing.empty?

    attributes = FILES.to_h { |attribute, file| [attribute, File.read(File.join(dir, file)).strip] }
    if attributes["notes"].length > NOTES_LIMIT
      raise ArgumentError, "notes.txt has #{attributes["notes"].length} characters; Apple allows #{NOTES_LIMIT}"
    end

    SECRETS.each { |attribute, name| attributes[attribute] = env[name].strip }
    attributes["demoAccountRequired"] = true
    attributes.sort.to_h
  end

  # A log line that names what was set, never a value.
  def self.describe(attributes)
    "App Review information set: #{attributes.keys.join(", ")}"
  end
end
