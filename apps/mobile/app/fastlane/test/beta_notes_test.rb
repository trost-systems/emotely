# frozen_string_literal: true

# Run from apps/mobile/app: bundle exec ruby fastlane/test/run.rb
#
# The beta notes Play shows testers of the closed `alpha` track (#317) and
# TestFlight shows as "What to Test". supply writes a note for every folder
# of the Play listing, an empty one where the file is missing, and Play
# refuses more than 500 characters only when the promotion commits.
require "minitest/autorun"
require_relative "../lib/beta_notes"

class BetaNotesTest < Minitest::Test
  PLAY_LIMIT = 500

  def play_locales
    Dir.children(BetaNotes::DIR).select { |entry| File.directory?(File.join(BetaNotes::DIR, entry)) }.sort
  end

  def test_the_notes_are_in_english_and_german
    assert_includes play_locales, "en-US"
    assert_includes play_locales, "de-DE"
  end

  def test_every_language_of_the_play_listing_has_a_note
    play_locales.each do |locale|
      assert File.file?(BetaNotes.path(locale)), "#{locale} has no #{BetaNotes.path(locale)}"
      refute_empty BetaNotes.text(locale).strip, "#{locale}'s note is blank"
    end
  end

  def test_every_note_fits_plays_500_characters
    play_locales.each do |locale|
      length = BetaNotes.text(locale).length

      assert_operator length, :<=, PLAY_LIMIT, "#{locale}'s note has #{length} characters"
    end
  end

  def test_no_note_ends_in_a_newline_which_supply_would_upload
    play_locales.each { |locale| refute BetaNotes.text(locale).end_with?("\n"), locale }
  end

  def test_testers_are_told_where_to_send_feedback
    play_locales.each { |locale| assert_includes BetaNotes.text(locale), "hello@getemotely.com", locale }
  end
end
