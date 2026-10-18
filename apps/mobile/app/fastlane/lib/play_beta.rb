# frozen_string_literal: true

require_relative "beta_notes"

# The Play side of the beta stage: promoting the internal release to the
# closed `alpha` track, with the beta notes as its release notes.
#
# Promotion and notes go in one edit, through supply (fastlane 2.240.1,
# supply/lib/supply/uploader.rb). In an edit without binaries,
# Uploader#perform_upload calls promote_track, which copies the internal
# release to `alpha`, and then perform_upload_meta on `alpha`: that finds the
# release by `version_code` (fetch_track_and_release!), reads each language
# folder's changelogs/<version code>.txt or changelogs/default.txt
# (upload_changelog) and writes them onto the release before the commit
# (upload_changelogs). Two things follow from the source:
#
# - `version_code` is required. Without it upload_changelog fails ("no
#   version code given"), although promote_track alone would find the
#   internal release by status.
# - Every folder under metadata_path is a language and gets a note; one
#   without a changelog file gets an empty one.
#
# A second edit for the notes after the promotion would be refused: the
# promotion's commit sends the alpha release to Google's review, and every
# commit refuses to touch changes in review (play_review_guard.rb).
module PlayBeta
  FROM = "internal"
  TO = "alpha"

  # supply's options for the promotion of `version_code`, on top of the
  # lanes' Play defaults (which skip every kind of upload).
  def self.promotion(version_code:)
    {
      skip_upload_aab: true,
      skip_upload_apk: true,
      track: FROM,
      track_promote_to: TO,
      version_code: Integer(version_code),
      skip_upload_changelogs: false,
      metadata_path: BetaNotes::DIR
    }
  end

  # The version code of the release supply promotes when it is given none:
  # the internal track's one completed release (promote_track selects by
  # release_status, `completed` by default). Read in an edit of its own that
  # is deleted again, as supply's own Reader does, before the promotion's
  # edit begins; nothing is committed, so no other edit is invalidated.
  # `client` is a Supply::Client.
  def self.newest_internal_version_code(client, package_name)
    client.begin_edit(package_name: package_name)
    track = begin
      client.get_edit_track(FROM)
    ensure
      client.abort_current_edit
    end

    completed = Array(track&.releases).select { |release| release.status == Supply::ReleaseStatus::COMPLETED }
    codes = completed.flat_map { |release| Array(release.version_codes) }
    unless completed.size == 1 && codes.size == 1
      FastlaneCore::UI.user_error!(
        "Play's #{FROM} track has #{completed.size} completed releases (version codes: " \
        "#{codes.empty? ? "none" : codes.join(", ")}), so which one to promote is unclear. " \
        "Run again with build_number set to the build to promote."
      )
    end
    Integer(codes.first)
  end
end
