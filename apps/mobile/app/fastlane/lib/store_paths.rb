# frozen_string_literal: true

# Where the release lanes find what the repository keeps, as absolute paths.
#
# fastlane runs a lane's own code inside fastlane/ but its actions (deliver,
# supply) in the parent directory, so FastlaneCore::FastlaneFolder.path ("./"
# while the Fastfile loads) and any path built from it point somewhere else
# by the time an action reads them. On main's first store-listings run
# (37117064456) deliver found no ./metadata and uploaded nothing, and supply
# failed on ./metadata/android. Built from this file's own location, these
# paths are right from anywhere.
module StorePaths
  FASTLANE_DIR = File.expand_path("..", __dir__)

  # apps/mobile/app, where flutter builds.
  APP_DIR = File.expand_path("..", FASTLANE_DIR)

  # The store listings, English and German, in deliver's layout; Play's under
  # android/ in supply's. scripts/store-listing-check.sh guards their limits.
  METADATA_DIR = File.join(FASTLANE_DIR, "metadata")

  # App Review information for Apple's reviewer, without its secrets (see
  # lib/app_review_information.rb). Outside metadata/ because deliver would
  # read a review_information/ folder there itself.
  APP_REVIEW_DIR = File.join(FASTLANE_DIR, "app_review")

  # Play's Data safety declaration, as the Play Console exports it (see
  # lib/play_data_safety.rb).
  DATA_SAFETY_CSV = File.join(FASTLANE_DIR, "data_safety.csv")
end
