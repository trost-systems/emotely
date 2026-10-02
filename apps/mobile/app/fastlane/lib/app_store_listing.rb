# frozen_string_literal: true

# When the App Store listing in fastlane/metadata can be uploaded, and how a
# skipped upload is reported.
#
# deliver writes to the version in preparation. Apple lets its metadata change
# while the version is being prepared or after a rejection; once it is
# submitted, in review or live, description, keywords, URLs, name and subtitle
# wait for the next version
# (https://developer.apple.com/help/app-store-connect/reference/required-localizable-and-editable-properties).
# deliver itself would retry for about 20 minutes and then fail, so the lane
# asks first and skips instead.
module AppStoreListing
  # appVersionState values whose listing deliver may write.
  UPLOADABLE_STATES = %w[PREPARE_FOR_SUBMISSION DEVELOPER_REJECTED REJECTED METADATA_REJECTED].freeze

  # Why the listing cannot be uploaded now, or nil when it can.
  def self.skip_reason(version_string, state)
    if version_string.nil?
      "App Store Connect has no version in preparation; the listing goes up " \
        "with the next app-release run after one is created."
    elsif !UPLOADABLE_STATES.include?(state)
      "version #{version_string} is #{state}, so its listing is fixed; the " \
        "listing goes up with the next version in preparation."
    end
  end

  # Reports a skipped upload: a notice annotation on GitHub Actions, so the
  # run stays green but says so; plain text anywhere else.
  def self.notice(message, title: "App Store listing not uploaded", out: $stdout, env: ENV)
    if env["GITHUB_ACTIONS"] == "true"
      out.puts("::notice title=#{title}::#{message}")
    else
      out.puts("#{title}: #{message}")
    end
  end
end
