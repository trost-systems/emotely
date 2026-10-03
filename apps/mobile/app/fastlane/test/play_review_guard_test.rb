# frozen_string_literal: true

# Run from apps/mobile/app: bundle exec ruby fastlane/test/run.rb
require "minitest/autorun"
require "google/apis/androidpublisher_v3"
require_relative "../lib/play_review_guard"

class PlayReviewGuardTest < Minitest::Test
  # The service, with the HTTP call replaced: records the command it would
  # send, or raises the error a test hands it.
  def service(raises: nil)
    service = Google::Apis::AndroidpublisherV3::AndroidPublisherService.new
    sent = []
    service.define_singleton_method(:execute_or_queue_command) do |command, &_block|
      sent << command
      raise raises if raises

      :committed
    end
    [service, sent]
  end

  def test_supply_commits_through_the_guarded_service
    require "fastlane"
    require "supply"

    assert_includes Supply::Client::SERVICE.ancestors, PlayReviewGuard
  end

  def test_a_commit_refuses_to_cancel_changes_in_review_by_default
    publisher, sent = service
    publisher.commit_edit("de.emotely.emotely", "edit-1")

    assert_equal "ERROR_IF_IN_REVIEW", sent.first.query["changesInReviewBehavior"]
  end

  def test_other_commit_parameters_still_reach_google
    publisher, sent = service
    publisher.commit_edit("de.emotely.emotely", "edit-1", changes_not_sent_for_review: true)

    assert_equal true, sent.first.query["changesNotSentForReview"]
    assert_equal "ERROR_IF_IN_REVIEW", sent.first.query["changesInReviewBehavior"]
  end

  def test_an_explicit_behavior_is_kept
    publisher, sent = service
    publisher.commit_edit("de.emotely.emotely", "edit-1", changes_in_review_behavior: "CANCEL_IN_REVIEW_AND_SUBMIT")

    assert_equal "CANCEL_IN_REVIEW_AND_SUBMIT", sent.first.query["changesInReviewBehavior"]
  end

  def test_a_refused_commit_says_why_and_keeps_googles_answer
    refusal = Google::Apis::ClientError.new("badRequest", status_code: 400, body: '{"error":{"message":"in review"}}')
    publisher, = service(raises: refusal)

    error = assert_raises(Google::Apis::ClientError) { publisher.commit_edit("de.emotely.emotely", "edit-1") }
    assert_includes error.message, "ERROR_IF_IN_REVIEW"
    assert_includes error.message, "badRequest"
    assert_equal 400, error.status_code
    assert_equal '{"error":{"message":"in review"}}', error.body
  end
end
