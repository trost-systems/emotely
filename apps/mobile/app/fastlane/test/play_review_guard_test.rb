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

  # Google's answer as the client raises it.
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

  def commit(publisher)
    publisher.commit_edit("de.emotely.emotely", "edit-1")
  end

  def test_supply_commits_through_the_guarded_service
    require "fastlane"
    require "supply"

    assert_includes Supply::Client::SERVICE.ancestors, PlayReviewGuard
  end

  def test_a_commit_refuses_to_cancel_changes_in_review_by_default
    publisher, sent = service
    commit(publisher)

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
    publisher, sent = service(raises: other)

    error = assert_raises(Google::Apis::ClientError) { commit(publisher) }
    assert_includes error.message, "ERROR_IF_IN_REVIEW"
    assert_includes error.message, "badRequest"
    assert_equal 400, error.status_code
    assert_equal '{"error":{"message":"bad bundle"}}', error.body
    assert_equal [:post], sent.map(&:method), "an edit refused for another reason is left alone"
  end

  # The refusal for changes in review still fails the lane, as a ClientError
  # supply reports like any other, but says what to do about it.
  def test_changes_in_review_fail_with_what_to_do
    publisher, = service(raises: refusal)

    error = assert_raises(Google::Apis::ClientError) { commit(publisher) }
    assert_includes error.message, "Play has changes in review; re-run this job once Google's review is done."
    assert_equal 400, error.status_code
    assert_equal JSON.generate(IN_REVIEW), error.body
  end

  # Google keeps a refused edit open ("this won't invalidate the edit"), with
  # the uploaded build in it; the guard deletes it.
  def test_the_edit_refused_for_changes_in_review_is_deleted
    publisher, sent = service(raises: refusal)

    assert_raises(Google::Apis::ClientError) { commit(publisher) }
    delete = sent.find { |command| command.method == :delete }
    refute_nil delete, "no edits.delete was sent"
    assert_equal({ "packageName" => "de.emotely.emotely", "editId" => "edit-1" }, delete.params)
  end

  def test_an_edit_that_cannot_be_deleted_still_fails_with_what_to_do
    gone = Google::Apis::ClientError.new("notFound", status_code: 404)
    publisher, = service(raises: refusal, delete_raises: gone)

    error = assert_raises(Google::Apis::ClientError) { commit(publisher) }
    assert_includes error.message, "re-run this job once Google's review is done"
  end

  def test_googles_documented_refusal_is_changes_in_review
    assert PlayReviewGuard.changes_in_review?(refusal)
  end

  def test_another_failed_precondition_is_not_changes_in_review
    other = IN_REVIEW["error"]["details"].first.merge("reason" => "APK_NOT_FOUND")

    refute PlayReviewGuard.changes_in_review?(refusal(in_review_with("details" => [other])))
  end

  def test_the_reason_without_failed_precondition_is_not_changes_in_review
    refute PlayReviewGuard.changes_in_review?(refusal(in_review_with("status" => "INVALID_ARGUMENT")))
  end

  def test_the_reason_outside_an_error_info_is_not_changes_in_review
    help = IN_REVIEW["error"]["details"].first.merge("@type" => "type.googleapis.com/google.rpc.Help")

    refute PlayReviewGuard.changes_in_review?(refusal(in_review_with("details" => [help])))
  end

  def test_the_reason_in_the_message_alone_is_not_changes_in_review
    words = { "error" => IN_REVIEW["error"].merge("message" => "CHANGES_ALREADY_IN_REVIEW").except("details") }

    refute PlayReviewGuard.changes_in_review?(refusal(words))
  end

  def test_the_reason_with_another_http_status_is_not_changes_in_review
    refute PlayReviewGuard.changes_in_review?(refusal(status_code: 409))
  end

  def test_a_body_that_is_not_json_is_not_changes_in_review
    garbled = Google::Apis::ClientError.new("badRequest", status_code: 400, body: "<html>CHANGES_ALREADY_IN_REVIEW</html>")

    refute PlayReviewGuard.changes_in_review?(garbled)
  end
end
