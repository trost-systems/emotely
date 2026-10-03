# frozen_string_literal: true

require "google/apis/androidpublisher_v3"

# Play's Data safety declaration, kept as the CSV the Play Console exports
# (App content → Data safety → Export to CSV) and written back whole with
# POST applications/{packageName}/dataSafety
# (https://developers.google.com/android-publisher/api-ref/rest/v3/applications/dataSafety).
# supply has no action for it; the Google client in the bundle has the call.
# An upload replaces every answer, so the CSV in the repository is the whole
# declaration, never a part of it.
module PlayDataSafety
  # Why the declaration cannot be uploaded from `path`, or nil when it can.
  def self.skip_reason(path)
    unless File.exist?(path)
      return "#{File.basename(path)} is not in the repository yet: export it in the Play Console " \
             "(App content → Data safety → Export to CSV) and commit it."
    end
    return "#{File.basename(path)} is empty." if File.read(path).strip.empty?

    nil
  end

  # Writes the declaration in `path` for `package_name` through `service`, an
  # AndroidPublisherService that is already authorized.
  def self.upload(service, package_name, path)
    request = Google::Apis::AndroidpublisherV3::SafetyLabelsUpdateRequest.new(safety_labels: File.read(path))
    service.data_application_safety(package_name, request)
  end
end
