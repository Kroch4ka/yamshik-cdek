# frozen_string_literal: true

require "vcr"

VCR.configure do |config|
  config.cassette_library_dir = "spec/cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.filter_sensitive_data("<CDEK_CLIENT_ID>") { ENV.fetch("CDEK_CLIENT_ID", nil) }
  config.filter_sensitive_data("<CDEK_CLIENT_SECRET>") { ENV.fetch("CDEK_CLIENT_SECRET", nil) }
end
