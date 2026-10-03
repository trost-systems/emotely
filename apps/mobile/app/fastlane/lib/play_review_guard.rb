# frozen_string_literal: true

require "json"
require "google/apis/androidpublisher_v3"

# Every Play edit the lanes commit refuses to touch changes that are in
# Google's review, instead of pulling them back.
#
# `edits.commit` defaults `changesInReviewBehavior` to
# CANCEL_IN_REVIEW_AND_SUBMIT: a commit cancels whatever is in review (a
# closed-testing `alpha` release, a listing change) and resubmits it with the
# new changes, so the review starts over and nobody is told
# (https://developers.google.com/android-publisher/api-ref/rest/v3/edits/commit).
# supply 2.240.1 passes only `changes_not_sent_for_review` to the client
# (supply/lib/supply/client.rb, Client#commit_current_edit!) and has no
# option for this, so the default is changed one layer down, in the Google
# API client every supply call goes through. An explicit value still wins.
# Upstream: fastlane has no such option yet; when supply gains one, the lanes
# pass it and this file goes.
#
# With ERROR_IF_IN_REVIEW Google refuses a commit that would send something
# new for review while something else is in review (an internal-track build
# is not refused, see the release-app skill). That refusal, recognized
# exactly, deletes the refused edit and fails with what to do: re-run the job
# once the review is done. Every other refusal fails with the general hint.
module PlayReviewGuard
  BEHAVIOR = "ERROR_IF_IN_REVIEW"

  HINT = "Play refused the commit. The lanes commit with #{BEHAVIOR} so that " \
         "changes in Google's review (an alpha release, a listing) are never " \
         "canceled and resubmitted; if something is in review, run this again " \
         "once Google has finished. Google said:"

  IN_REVIEW_HINT = "Play has changes in review; re-run this job once Google's review is done. " \
                   "The lanes commit with #{BEHAVIOR}, so nothing in review was canceled, and the " \
                   "refused edit was deleted. Google said:"

  # Whether `error` is Google's refusal of a commit because the app already
  # has changes in review, exactly as edits.commit documents it: HTTP 400,
  # status FAILED_PRECONDITION, and an ErrorInfo detail whose reason is
  # CHANGES_ALREADY_IN_REVIEW. Read from the JSON body, never from the words.
  def self.changes_in_review?(error)
    return false unless error.is_a?(Google::Apis::ClientError) && error.status_code == 400

    body = JSON.parse(error.body.to_s)["error"]
    return false unless body.is_a?(Hash) && body["status"] == "FAILED_PRECONDITION"

    Array(body["details"]).any? do |detail|
      detail.is_a?(Hash) &&
        detail["@type"] == "type.googleapis.com/google.rpc.ErrorInfo" &&
        detail["reason"] == "CHANGES_ALREADY_IN_REVIEW"
    end
  rescue JSON::ParserError
    false
  end

  def commit_edit(package_name, edit_id, changes_in_review_behavior: nil, **rest, &block)
    super(package_name, edit_id, changes_in_review_behavior: changes_in_review_behavior || BEHAVIOR, **rest, &block)
  rescue Google::Apis::ClientError => e
    hint = HINT
    if PlayReviewGuard.changes_in_review?(e)
      discard_edit(package_name, edit_id)
      hint = IN_REVIEW_HINT
    end
    raise e.class.new("#{hint} #{e.message}", status_code: e.status_code, header: e.header, body: e.body)
  end

  private

  # Google keeps a refused edit open ("this won't invalidate the edit"), with
  # the uploaded build in it, until it expires. If the delete fails too, it
  # simply expires.
  def discard_edit(package_name, edit_id)
    delete_edit(package_name, edit_id)
  rescue Google::Apis::Error
    nil
  end
end

Google::Apis::AndroidpublisherV3::AndroidPublisherService.prepend(PlayReviewGuard)
