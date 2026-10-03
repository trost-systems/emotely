# frozen_string_literal: true

# Whether a build Play refused for the internal track still has to go up.
#
# `android internal` defers its upload, green, when Play refuses the commit
# because something is in Google's review (PlayReviewGuard::ChangesInReview),
# and app-release keeps that build's App Bundle as an artifact. The
# play-internal-catch-up workflow brings it back every hour: `android
# catch_up` asks Play what the internal track holds and uploads the deferred
# build only if it is newer. Build numbers only grow (1000 + app-release's run
# number), so "newer" is a plain comparison of version codes.
module PlayInternalTrack
  # The highest version code on any release of the track, or nil when it has
  # none. `releases` are applications.tracks.releases.list's ReleaseSummary
  # objects: every release Play keeps for the track, whatever its state, so a
  # build already there in any form is never uploaded again.
  def self.newest_version_code(releases)
    Array(releases).flat_map { |release| Array(release.active_artifacts).map(&:version_code) }.compact.max
  end

  # Why the deferred `build` (its number, as a string) is not uploaded, or nil
  # when it is newer than everything on the internal track.
  def self.skip_reason(newest_version_code, build)
    build = Integer(build, 10)
    return nil if newest_version_code.nil? || build > newest_version_code

    "the internal track already has #{newest_version_code}, so the deferred build #{build} " \
      "is not uploaded; nothing to catch up."
  end
end
