# frozen_string_literal: true

module Yamshik
  module Cdek
    module V2
      # CDEK API v2 adapter.
      #
      # CDEK deduplicates order creation by the client's order number
      # (+Parcel#reference+ → +number+): a repeated submission is refused with
      # a "already exists" validation error, which the adapter maps to
      # CarrierError code :duplicate (DESIGN.md §3).
      #
      # Carrier options (DESIGN.md §5), validated strictly:
      # - +tariff_code+ [String, Integer] — required, CDEK tariff to create the order with;
      # - +shipment_point+ [String] — sender warehouse/pickup-point code override;
      # - +developer_key+ [String] — CDEK developer key.
      class Adapter < Yamshik::Carrier
        PRODUCTION_URL = "https://api.cdek.ru/v2"
        SANDBOX_URL = "https://api.edu.cdek.ru/v2"

        ALLOWED_CARRIER_OPTIONS = %i[tariff_code shipment_point developer_key].freeze

        creation_strategy :idempotent

        # @param client_id [String] CDEK OAuth2 client id
        # @param client_secret [String] CDEK OAuth2 client secret
        # @param sandbox [Boolean] use the CDEK test environment (api.edu.cdek.ru)
        # @param http [Yamshik::HTTP::Client, nil] injected for tests
        # @param auth_http [Yamshik::HTTP::Client, nil] injected for tests
        # @param logger [Logger, nil]
        def initialize(client_id:, client_secret:, sandbox: false, http: nil, auth_http: nil, logger: nil, **)
          super()
          base_url = sandbox ? SANDBOX_URL : PRODUCTION_URL
          @http = http || Yamshik::HTTP::Client.new(base_url:, logger:)
          @auth = Auth.new(client_id:, client_secret:,
                           http: auth_http || Yamshik::HTTP::Client.new(base_url:, logger:))
        end

        # @see Yamshik::Carrier#create_order
        def create_order(parcel, carrier_options: {})
          validation = validate_creation(parcel, carrier_options)
          return validation if validation

          response = http.post("orders", body: PayloadBuilder.call(parcel, carrier_options),
                                         headers: auth_headers, idempotent: true)
          return Result.ok(ParcelMapper.from_creation(parcel, response)) if response.status.between?(200, 299)

          Result.err(ErrorMapper.call(response))
        end

        # @see Yamshik::Carrier#parcel
        def parcel(external_id)
          response = http.get("orders/#{external_id}", headers: auth_headers)
          return Result.ok(ParcelMapper.from_order(response)) if response.status == 200

          Result.err(ErrorMapper.call(response))
        end

        private

        attr_reader :http, :auth

        def validate_creation(parcel, carrier_options)
          unknown = carrier_options.keys - ALLOWED_CARRIER_OPTIONS
          return failure("unknown carrier_options keys: #{unknown.inspect}", path: "carrier_options") if unknown.any?
          unless carrier_options[:tariff_code]
            return failure("tariff_code is required", path: "carrier_options.tariff_code")
          end
          return failure("at least one place is required", path: "places") if parcel.places.empty?

          nil
        end

        def failure(message, path:)
          Result.err(Yamshik::CarrierError.new(code: :validation_failed, carrier: :cdek,
                                               message:, details: { path: }))
        end

        def auth_headers
          { "Authorization" => "Bearer #{auth.token}" }
        end
      end
    end
  end
end
