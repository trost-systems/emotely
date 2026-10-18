# frozen_string_literal: true

# Run from apps/mobile/app: bundle exec ruby fastlane/test/run.rb
#
# `fastlane android beta` promotes the internal release to the closed `alpha`
# track. Without release notes of its own, Play showed testers the legacy
# production release's shutdown note (#317), so the promotion carries the
# beta notes in every language the Play listing has. The tests run supply's
# own uploader with the lane's options against a stand-in for Play.
require "minitest/autorun"
require "fastlane"
require "supply"
require_relative "../lib/play_beta"
require_relative "../lib/beta_notes"

class PlayBetaTest < Minitest::Test
  AndroidPublisher = Google::Apis::AndroidpublisherV3

  # Play's side of one edit, kept in memory: the tracks as the edit sees
  # them, and every call that would reach Google.
  class FakePlay
    attr_reader :calls, :tracks_by_name

    def initialize(tracks)
      @tracks_by_name = tracks.to_h { |track| [track.track, track] }
      @calls = []
    end

    def begin_edit(package_name:)
      @calls << [:begin_edit, package_name]
    end

    def tracks(*names)
      @tracks_by_name.values.select { |track| names.empty? || names.include?(track.track) }
    end

    def update_track(name, track)
      @calls << [:update_track, name]
      @tracks_by_name[name] = track
    end

    def upload_changelogs(track, name)
      @calls << [:upload_changelogs, name]
      @tracks_by_name[name] = track
    end

    def listing_for_language(_language) = nil

    def commit_current_edit!
      @calls << [:commit]
    end
  end

  def release(code, status: "completed")
    AndroidPublisher::TrackRelease.new(name: "2.0.0 (#{code})", status: status, version_codes: [code.to_s])
  end

  def track(name, *releases)
    AndroidPublisher::Track.new(track: name, releases: releases)
  end

  # Runs supply as `fastlane android beta` does, against `play`.
  def promote(play, version_code:)
    options = {
      package_name: "de.emotely.emotely",
      json_key_data: "{}",
      skip_upload_metadata: true,
      skip_upload_changelogs: true,
      skip_upload_images: true,
      skip_upload_screenshots: true
    }.merge(PlayBeta.promotion(version_code: version_code))
    Supply.config = FastlaneCore::Configuration.create(Supply::Options.available_options, options)
    original = Supply::Client.method(:make_from_config)
    Supply::Client.define_singleton_method(:make_from_config) { |**| play }
    # supply's summary table and progress, which the test does not read.
    capture_subprocess_io { Supply::Uploader.new.perform_upload }
  ensure
    Supply::Client.define_singleton_method(:make_from_config, original) if original
  end

  def test_the_promoted_alpha_release_carries_the_beta_notes_in_every_listing_language
    play = FakePlay.new([track("internal", release(1065)), track("alpha", release(1040))])
    promote(play, version_code: 1065)

    alpha = play.tracks_by_name.fetch("alpha").releases.find { |r| r.version_codes == ["1065"] }
    refute_nil alpha, "1065 was not promoted to alpha"
    notes = alpha.release_notes.to_h { |note| [note.language, note.text] }

    assert_equal %w[de-DE en-US], notes.keys.sort
    notes.each { |locale, text| assert_equal BetaNotes.text(locale), text, locale }
  end

  def test_the_promotion_and_its_notes_are_one_binary_free_edit
    play = FakePlay.new([track("internal", release(1065)), track("alpha")])
    promote(play, version_code: 1065)

    assert_equal [[:begin_edit, "de.emotely.emotely"], [:update_track, "alpha"], [:upload_changelogs, "alpha"], [:commit]],
                 play.calls
  end

  # Play's side of a read: an edit that is opened, read and deleted.
  class FakeReader
    attr_reader :calls

    def initialize(internal, raises: nil)
      @internal = internal
      @raises = raises
      @calls = []
    end

    def begin_edit(package_name:)
      @calls << [:begin_edit, package_name]
    end

    def get_edit_track(name)
      @calls << [:get_edit_track, name]
      raise @raises if @raises

      @internal
    end

    def abort_current_edit
      @calls << [:abort]
    end
  end

  def newest(reader)
    PlayBeta.newest_internal_version_code(reader, "de.emotely.emotely")
  end

  # What supply promotes without a version code: the internal track's
  # completed release (promote_track selects by release_status).
  def test_without_a_build_number_the_internal_tracks_completed_release_is_promoted
    reader = FakeReader.new(track("internal", release(1064, status: "draft"), release(1065)))

    assert_equal 1065, newest(reader)
  end

  def test_the_read_is_an_edit_that_is_deleted_again
    reader = FakeReader.new(track("internal", release(1065)))
    newest(reader)

    assert_equal [[:begin_edit, "de.emotely.emotely"], [:get_edit_track, "internal"], [:abort]], reader.calls
  end

  def test_the_read_edit_is_deleted_when_the_read_fails
    reader = FakeReader.new(nil, raises: Google::Apis::ServerError.new("backendError"))

    assert_raises(Google::Apis::ServerError) { newest(reader) }
    assert_equal [:abort], reader.calls.last
  end

  def test_no_completed_internal_release_fails_with_what_to_do
    [nil, track("internal"), track("internal", release(1065, status: "draft"))].each do |internal|
      error = assert_raises(FastlaneCore::Interface::FastlaneError) { newest(FakeReader.new(internal)) }

      assert_includes error.message, "build_number"
    end
  end

  def test_more_than_one_completed_internal_release_fails_with_what_to_do
    internal = track("internal", release(1064), release(1065))

    error = assert_raises(FastlaneCore::Interface::FastlaneError) { newest(FakeReader.new(internal)) }
    assert_includes error.message, "build_number"
  end
end
