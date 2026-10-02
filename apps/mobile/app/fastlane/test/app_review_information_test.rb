# frozen_string_literal: true

# Run from apps/mobile/app: bundle exec ruby fastlane/test/run.rb
require "minitest/autorun"
require "tmpdir"
require_relative "../lib/app_review_information"

class AppReviewInformationTest < Minitest::Test
  SECRETS = {
    "APP_REVIEW_DEMO_PASSWORD" => "pw-from-secret",
    "APP_REVIEW_CONTACT_PHONE" => "+49 000 0000000"
  }.freeze

  # A review-information folder as the repository keeps it, each file with
  # the final newline an editor adds.
  def folder(notes: "Open the app.")
    dir = Dir.mktmpdir
    {
      "first_name.txt" => "Peter",
      "last_name.txt" => "Trost",
      "email_address.txt" => "peter@example.com",
      "demo_user.txt" => "app-store-review@example.com",
      "notes.txt" => notes
    }.each { |name, text| File.write(File.join(dir, name), "#{text}\n") }
    dir
  end

  def test_files_and_secrets_make_the_review_detail
    attributes = AppReviewInformation.attributes(folder, env: SECRETS)

    assert_equal(
      {
        "contactFirstName" => "Peter",
        "contactLastName" => "Trost",
        "contactEmail" => "peter@example.com",
        "contactPhone" => "+49 000 0000000",
        "demoAccountName" => "app-store-review@example.com",
        "demoAccountPassword" => "pw-from-secret",
        "demoAccountRequired" => true,
        "notes" => "Open the app."
      },
      attributes
    )
  end

  def test_the_committed_folder_is_complete_and_within_apples_limits
    committed = File.expand_path("../app_review", __dir__)
    attributes = AppReviewInformation.attributes(committed, env: SECRETS)

    assert_equal "app-store-review@getemotely.com", attributes["demoAccountName"]
  end

  def test_a_missing_secret_is_named_and_its_value_never_appears
    error = assert_raises(AppReviewInformation::Missing) do
      AppReviewInformation.attributes(folder, env: { "APP_REVIEW_CONTACT_PHONE" => "+49 000 0000000" })
    end

    assert_includes error.message, "APP_REVIEW_DEMO_PASSWORD"
    refute_includes error.message, "+49"
  end

  def test_an_empty_secret_counts_as_missing
    env = SECRETS.merge("APP_REVIEW_CONTACT_PHONE" => " ")

    error = assert_raises(AppReviewInformation::Missing) { AppReviewInformation.attributes(folder, env: env) }
    assert_includes error.message, "APP_REVIEW_CONTACT_PHONE"
  end

  def test_a_missing_file_is_named
    dir = folder
    File.delete(File.join(dir, "demo_user.txt"))

    error = assert_raises(AppReviewInformation::Missing) { AppReviewInformation.attributes(dir, env: SECRETS) }
    assert_includes error.message, "demo_user.txt"
  end

  def test_notes_over_apples_4000_characters_are_refused
    error = assert_raises(ArgumentError) do
      AppReviewInformation.attributes(folder(notes: "a" * 4001), env: SECRETS)
    end

    assert_includes error.message, "4001"
  end

  def test_a_description_for_the_log_names_fields_but_no_values
    line = AppReviewInformation.describe(AppReviewInformation.attributes(folder, env: SECRETS))

    assert_includes line, "demoAccountPassword"
    refute_includes line, "pw-from-secret"
    refute_includes line, "+49"
  end
end
