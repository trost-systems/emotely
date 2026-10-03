# frozen_string_literal: true

# Run from apps/mobile/app: bundle exec ruby fastlane/test/run.rb
require "minitest/autorun"
require "json"
require "google/apis/androidpublisher_v3"
require_relative "../lib/play_review_guard"

class PlayReviewGuardTest < Minitest::Test
  # Google's answer to a commit with ERROR_IF_IN_REVIEW while the app has
  # changes in review, as edits.commit documents it ("Changes in review error
  # message sample").
  IN_REVIEW = {
    "error" => {
      "code" => 400,
      "message" => "You already have changes in review. Cancel this review or wait for it to complete " \
                   "before you try again. See https://developers.google.com/android-publisher/api-ref/rest/v3/applications.tracks.releases",
      "status" => "FAILED_PRECONDITION",
      "details" => [
        {
          "@type" => "type.googleapis.com/google.rpc.ErrorInfo",
          "reason" => "CHANGES_ALREADY_IN_REVIEW",
          "domain" => "googleapis.com",
          "metadata" => { "editId" => "123456790", "method" => "edits.commit" }
        }
      ]
    }
  }.freeze

  # The answer as the Google client raises it.
  def refusal(body = IN_REVIEW, status_code: 400)
    Google::Apis::ClientError.new("failedPrecondition: refused", status_code: status_code, body: JSON.generate(body))
  end

  # IN_REVIEW with `changes` merged into its "error" object.
  def in_review_with(changes)
    { "error" => IN_REVIEW["error"].merge(changes) }
  end

  # The service, with the HTTP call replaced: records the command it would
  # send, and raises the error a test hands it for a commit (`raises`) or for
  # a delete (`delete_raises`).
  def service(raises: nil, delete_raises: nil)
    service = Google::Apis::AndroidpublisherV3::AndroidPublisherService.new
    sent = []
    service.define_singleton_method(:execute_or_queue_command) do |command, &_block|
      sent << command
      error = command.method == :delete ? delete_raises : raises
      raise error if error

      :done
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
    other = Google::Apis::ClientError.new("badRequest", status_code: 400, body: '{"error":{"message":"bad bundle"}}')
    publisher, = service(raises: other)

    error = assert_raises(Google::Apis::ClientError) { publisher.commit_edit("de.emotely.emotely", "edit-1") }
    assert_includes error.message, "ERROR_IF_IN_REVIEW"
    assert_includes error.message, "badRequest"
    assert_equal 400, error.status_code
    assert_equal '{"error":{"message":"bad bundle"}}', error.body
  end

  # The one refusal a lane may end green on: its own exception, which is not
  # a Google::Apis::Error, so supply's call_google_api does not flatten it
  # into a FastlaneError string the lane could only match by its words.
  def test_changes_in_review_raise_their_own_error_with_googles_words
    publisher, = service(raises: refusal)

    error = assert_raises(PlayReviewGuard::ChangesInReview) { publisher.commit_edit("de.emotely.emotely", "edit-1") }
    refute_kind_of Google::Apis::Error, error
    assert_includes error.message, "ERROR_IF_IN_REVIEW"
    assert_includes error.message, "You already have changes in review"
    assert_equal IN_REVIEW["error"]["message"], error.google_message
  end

  # Google keeps a refused edit open ("this won't invalidate the edit"); the
  # guard throws it away so the build it holds goes with it.
  def test_the_refused_edit_is_deleted
    publisher, sent = service(raises: refusal)

    assert_raises(PlayReviewGuard::ChangesInReview) { publisher.commit_edit("de.emotely.emotely", "edit-1") }
    delete = sent.find { |command| command.method == :delete }
    refute_nil delete, "no edits.delete was sent"
    assert_equal({ "packageName" => "de.emotely.emotely", "editId" => "edit-1" }, delete.params)
  end

  def test_an_edit_that_cannot_be_deleted_still_reports_changes_in_review
    gone = Google::Apis::ClientError.new("notFound", status_code: 404)
    publisher, = service(raises: refusal, delete_raises: gone)

    assert_raises(PlayReviewGuard::ChangesInReview) { publisher.commit_edit("de.emotely.emotely", "edit-1") }
  end

  def test_another_failed_precondition_is_a_failure
    other = in_review_with("details" => [IN_REVIEW["error"]["details"].first.merge("reason" => "APK_NOT_FOUND")])
    publisher, = service(raises: refusal(other))

    assert_raises(Google::Apis::ClientError) { publisher.commit_edit("de.emotely.emotely", "edit-1") }
  end

  def test_the_reason_alone_is_not_enough_without_failed_precondition
    publisher, = service(raises: refusal(in_review_with("status" => "INVALID_ARGUMENT")))

    assert_raises(Google::Apis::ClientError) { publisher.commit_edit("de.emotely.emotely", "edit-1") }
  end

  def test_the_reason_must_come_from_an_error_info_detail
    help = IN_REVIEW["error"]["details"].first.merge("@type" => "type.googleapis.com/google.rpc.Help")
    publisher, = service(raises: refusal(in_review_with("details" => [help])))

    assert_raises(Google::Apis::ClientError) { publisher.commit_edit("de.emotely.emotely", "edit-1") }
  end

  def test_words_in_the_message_are_not_the_reason
    words = { "error" => IN_REVIEW["error"].merge("message" => "CHANGES_ALREADY_IN_REVIEW").except("details") }
    publisher, = service(raises: refusal(words))

    assert_raises(Google::Apis::ClientError) { publisher.commit_edit("de.emotely.emotely", "edit-1") }
  end

  def test_the_reason_with_another_http_status_is_a_failure
    publisher, = service(raises: refusal(status_code: 409))

    assert_raises(Google::Apis::ClientError) { publisher.commit_edit("de.emotely.emotely", "edit-1") }
  end

  def test_a_body_that_is_not_json_is_a_failure
    garbled = Google::Apis::ClientError.new("badRequest", status_code: 400, body: "<html>CHANGES_ALREADY_IN_REVIEW</html>")
    publisher, = service(raises: garbled)

    assert_raises(Google::Apis::ClientError) { publisher.commit_edit("de.emotely.emotely", "edit-1") }
  end
end
