# frozen_string_literal: true

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
# review; the error says so, and the run is repeated once the review is done.
module PlayReviewGuard
  BEHAVIOR = "ERROR_IF_IN_REVIEW"

  HINT = "Play refused the commit. The lanes commit with #{BEHAVIOR} so that " \
         "changes in Google's review (an alpha release, a listing) are never " \
         "cancelled and resubmitted; if something is in review, run this again " \
         "once Google has finished. Google said:"

  def commit_edit(package_name, edit_id, changes_in_review_behavior: nil, **rest, &block)
    super(package_name, edit_id, changes_in_review_behavior: changes_in_review_behavior || BEHAVIOR, **rest, &block)
  rescue Google::Apis::ClientError => e
    raise e.class.new("#{HINT} #{e.message}", status_code: e.status_code, header: e.header, body: e.body)
  end
end

Google::Apis::AndroidpublisherV3::AndroidPublisherService.prepend(PlayReviewGuard)
