# frozen_string_literal: true

# Run from apps/mobile/app: bundle exec ruby fastlane/test/run.rb
require "minitest/autorun"
require "google/apis/androidpublisher_v3"
require_relative "../lib/play_internal_track"

class PlayInternalTrackTest < Minitest::Test
  # A release as applications.tracks.releases.list returns it.
  def release(*version_codes, state: "RELEASE_LIFECYCLE_STATE_PUBLISHED")
    Google::Apis::AndroidpublisherV3::ReleaseSummary.new(
      track: "internal",
      release_lifecycle_state: state,
      active_artifacts: version_codes.map { |code| Google::Apis::AndroidpublisherV3::ArtifactSummary.new(version_code: code) }
    )
  end

  def test_the_newest_version_code_is_the_highest_on_any_release
    releases = [release(1120), release(1123, 1121, state: "RELEASE_LIFECYCLE_STATE_DRAFT")]

    assert_equal 1123, PlayInternalTrack.newest_version_code(releases)
  end

  def test_a_track_without_releases_has_no_version_code
    assert_nil PlayInternalTrack.newest_version_code([])
    assert_nil PlayInternalTrack.newest_version_code(nil)
  end

  def test_a_release_without_artifacts_has_no_version_code
    empty = Google::Apis::AndroidpublisherV3::ReleaseSummary.new(track: "internal")

    assert_nil PlayInternalTrack.newest_version_code([empty])
  end

  def test_a_build_newer_than_the_track_is_uploaded
    assert_nil PlayInternalTrack.skip_reason(1120, "1123")
  end

  def test_a_track_without_a_build_takes_any_build
    assert_nil PlayInternalTrack.skip_reason(nil, "1123")
  end

  def test_the_build_the_track_already_has_is_skipped_with_a_reason
    reason = PlayInternalTrack.skip_reason(1123, "1123")

    assert_includes reason, "1123"
    assert_includes reason, "internal"
  end

  # A later merge uploaded directly once the review was over: the deferred
  # build is older than what testers have and must never replace it.
  def test_a_build_older_than_the_track_is_skipped
    reason = PlayInternalTrack.skip_reason(1125, "1123")

    assert_includes reason, "1125"
    assert_includes reason, "1123"
  end

  def test_a_build_number_that_is_not_a_number_is_refused
    assert_raises(ArgumentError) { PlayInternalTrack.skip_reason(1120, "") }
    assert_raises(ArgumentError) { PlayInternalTrack.skip_reason(1120, "11a3") }
  end
end
