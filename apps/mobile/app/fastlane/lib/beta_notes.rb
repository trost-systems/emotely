# frozen_string_literal: true

require_relative "store_paths"

# What a beta tester reads about a build, per language: Play's release notes
# on the closed `alpha` track and TestFlight's "What to Test"
# (lib/test_flight_info.rb).
# The same for every build, since every build asks the same of a tester.
#
# The text is supply's default changelog in the Play listing's folders,
# metadata/android/<locale>/changelogs/default.txt: supply uploads it for
# any version code without a <version code>.txt of its own. No final
# newline, as for the rest of the Play listing; scripts/store-listing-check.sh
# holds every changelog to Play's 500 characters.
module BetaNotes
  DIR = File.join(StorePaths::METADATA_DIR, "android")

  def self.path(locale)
    File.join(DIR, locale, "changelogs", "default.txt")
  end

  def self.text(locale)
    File.read(path(locale), encoding: "UTF-8")
  end
end
