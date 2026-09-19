# frozen_string_literal: true

require "json"

module Yamshik
  module Cdek
    module V2
      # OAuth2 client-credentials token management for CDEK API v2.
      #
      # Tokens are cached and refreshed proactively (60s before expiry).
      # Thread-safe.
      class Auth
        REFRESH_MARGIN = 60

        # @param client_id [String]
        # @param client_secret [String]
        # @param http [Yamshik::HTTP::Client] client bound to the CDEK base URL
        def initialize(client_id:, client_secret:, http:)
          @client_id = client_id
          @client_secret = client_secret
          @http = http
          @mutex = Mutex.new
          @token = nil
          @expires_at = nil
        end

        # @return [String] a valid access token
        # @raise [Yamshik::AuthenticationError] on rejected credentials
        # @raise [Yamshik::InvalidResponseError] on an unparseable token response
        def token
          @mutex.synchronize do
            return @token if fresh?

            fetch_token
          end
        end

        private

        def fresh?
          @token && @expires_at && Time.now < @expires_at
        end

        def fetch_token
          response = @http.post(
            "oauth/token?grant_type=client_credentials&client_id=#{@client_id}&client_secret=#{@client_secret}",
            idempotent: true
          )

          body = parse(response.body)
          @token = body.fetch("access_token")
          @expires_at = Time.now + body.fetch("expires_in", 3600) - REFRESH_MARGIN
          @token
        rescue KeyError => e
          raise Yamshik::InvalidResponseError, "CDEK token response misses #{e.key.inspect}"
        end

        def parse(body)
          JSON.parse(body)
        rescue JSON::ParserError
          raise Yamshik::InvalidResponseError, "CDEK token response is not valid JSON"
        end
      end
    end
  end
end
