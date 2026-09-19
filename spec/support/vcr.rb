# frozen_string_literal: true

require "vcr"
require "webmock/rspec"

WebMock.disable_net_connect!(allow_localhost: true)

VCR.configure do |config|
  config.cassette_library_dir = "spec/cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!
  # Specs use hand-written WebMock stubs (built from the API docs examples)
  # until sandbox credentials allow recording real cassettes (yamshik#8).
  config.allow_http_connections_when_no_cassette = true
  config.filter_sensitive_data("<CDEK_CLIENT_ID>") { ENV.fetch("CDEK_CLIENT_ID", nil) }
  config.filter_sensitive_data("<CDEK_CLIENT_SECRET>") { ENV.fetch("CDEK_CLIENT_SECRET", nil) }
end
