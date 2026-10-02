# frozen_string_literal: true

# Run from apps/mobile/app: bundle exec ruby fastlane/test/run.rb
require "minitest/autorun"
require "stringio"
require_relative "../lib/app_store_listing"

class AppStoreListingTest < Minitest::Test
  def test_a_version_in_preparation_takes_the_listing
    assert_nil AppStoreListing.skip_reason("2.0.0", "PREPARE_FOR_SUBMISSION")
  end

  def test_a_rejected_version_takes_the_listing
    %w[DEVELOPER_REJECTED REJECTED METADATA_REJECTED].each do |state|
      assert_nil AppStoreListing.skip_reason("2.0.0", state), state
    end
  end

  def test_no_version_in_preparation_is_skipped_with_a_reason
    reason = AppStoreListing.skip_reason(nil, nil)

    assert_includes reason, "no version in preparation"
  end

  def test_a_version_apple_is_reviewing_is_skipped_with_its_state
    %w[WAITING_FOR_REVIEW IN_REVIEW READY_FOR_REVIEW INVALID_BINARY].each do |state|
      reason = AppStoreListing.skip_reason("2.0.0", state)

      refute_nil reason, state
      assert_includes reason, "2.0.0"
      assert_includes reason, state
    end
  end

  def test_a_notice_is_a_github_annotation_on_actions
    out = StringIO.new
    AppStoreListing.notice("skipped", out: out, env: { "GITHUB_ACTIONS" => "true" })

    assert_equal "::notice title=App Store listing not uploaded::skipped\n", out.string
  end

  def test_a_notice_can_carry_its_own_title
    out = StringIO.new
    AppStoreListing.notice("no secret", title: "App Review information not updated", out: out, env: { "GITHUB_ACTIONS" => "true" })

    assert_equal "::notice title=App Review information not updated::no secret\n", out.string
  end

  def test_a_notice_is_plain_text_elsewhere
    out = StringIO.new
    AppStoreListing.notice("skipped", out: out, env: {})

    assert_equal "App Store listing not uploaded: skipped\n", out.string
  end
end
