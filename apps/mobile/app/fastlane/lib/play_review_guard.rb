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
# With ERROR_IF_IN_REVIEW Google refuses the commit while something is in
# review. That refusal, and only that one, raises ChangesInReview, which a
# lane may answer by trying again later (`android internal` does, and the
# play-internal-catch-up workflow tries again every hour); every other
# refusal stays a Google::Apis::ClientError and fails the lane.
module PlayReviewGuard
  BEHAVIOR = "ERROR_IF_IN_REVIEW"

  HINT = "Play refused the commit. The lanes commit with #{BEHAVIOR} so that " \
         "changes in Google's review (an alpha release, a listing) are never " \
         "canceled and resubmitted; if something is in review, run this again " \
         "once Google has finished. Google said:"

  # The commit was refused because the app has changes in Google's review;
  # nothing was published. Deliberately not a Google::Apis::Error: supply's
  # Client#call_google_api turns those into a FastlaneError that keeps only
  # Google's words, and a lane must be able to tell this refusal apart from
  # every other one without matching words.
  class ChangesInReview < StandardError
    # Google's own words, for a lane that reports the refusal itself.
    attr_reader :google_message

    def initialize(google_message)
      @google_message = google_message
      super("Play refused the commit because the app has changes in Google's review; the lanes commit " \
            "with #{BEHAVIOR}, so nothing in review was canceled. Run this again once Google has " \
            "finished. Google said: #{google_message}")
    end
  end

  # Whether `error` is Google's refusal of a commit because the app already
  # has changes in review, exactly as edits.commit documents it: HTTP 400,
  # status FAILED_PRECONDITION, and an ErrorInfo detail whose reason is
  # CHANGES_ALREADY_IN_REVIEW. Anything less, or a body that is not JSON, is
  # not: an unknown refusal must fail, never be waited out.
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
    raise e.class.new("#{HINT} #{e.message}", status_code: e.status_code, header: e.header, body: e.body) unless PlayReviewGuard.changes_in_review?(e)

    discard_edit(package_name, edit_id)
    raise ChangesInReview.new(JSON.parse(e.body)["error"]["message"].to_s)
  end

  private

  # Google keeps a refused edit open ("this won't invalidate the edit"), with
  # whatever it holds, until it expires. Deleting it drops the uploaded build
  # with it; if that fails, the edit simply expires.
  def discard_edit(package_name, edit_id)
    delete_edit(package_name, edit_id)
  rescue Google::Apis::Error
    nil
  end
end

Google::Apis::AndroidpublisherV3::AndroidPublisherService.prepend(PlayReviewGuard)
