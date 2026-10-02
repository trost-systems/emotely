# frozen_string_literal: true

# Run from apps/mobile/app: bundle exec ruby fastlane/test/run.rb
require "minitest/autorun"
require "tmpdir"
require "google/apis/androidpublisher_v3"
require_relative "../lib/play_data_safety"

class PlayDataSafetyTest < Minitest::Test
  CSV = "Question ID (machine readable),Response ID (machine readable),Response value\n" \
        "PSL_DATA_COLLECTION_COLLECTS_PERSONAL_DATA,,true\n"

  # The service, with the HTTP call replaced: records the command it would
  # send.
  def service
    service = Google::Apis::AndroidpublisherV3::AndroidPublisherService.new
    sent = []
    service.define_singleton_method(:execute_or_queue_command) do |command, &_block|
      sent << command
      :written
    end
    [service, sent]
  end

  def csv_file(text = CSV)
    path = File.join(Dir.mktmpdir, "data_safety.csv")
    File.write(path, text)
    path
  end

  def test_the_csv_is_posted_as_the_apps_safety_labels
    publisher, sent = service
    PlayDataSafety.upload(publisher, "de.emotely.emotely", csv_file)

    command = sent.first
    assert_equal :post, command.method
    assert_equal "de.emotely.emotely", command.params["packageName"]
    assert_includes command.url.pattern, "applications/{packageName}/dataSafety"
    assert_equal CSV, command.request_object.safety_labels
  end

  def test_no_csv_yet_is_a_reason_to_skip_not_a_request
    publisher, sent = service
    reason = PlayDataSafety.skip_reason(File.join(Dir.mktmpdir, "data_safety.csv"))

    assert_includes reason, "Export to CSV"
    assert_empty sent
    refute_nil publisher
  end

  def test_an_empty_csv_is_a_reason_to_skip
    assert_includes PlayDataSafety.skip_reason(csv_file("")), "empty"
  end

  def test_a_csv_with_content_has_no_reason_to_skip
    assert_nil PlayDataSafety.skip_reason(csv_file)
  end
end
