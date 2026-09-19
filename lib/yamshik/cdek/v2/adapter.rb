# frozen_string_literal: true

module Yamshik
  module Cdek
    module V2
      # CDEK API v2 adapter.
      #
      # CDEK deduplicates order creation by the client's order number
      # (+Parcel#reference+ → +number+), so creation is idempotent.
      #
      # Contract methods (create_order, parcel) are implemented in the scope
      # of https://github.com/Kroch4ka/yamshik/issues/8
      class Adapter < Yamshik::Carrier
        creation_strategy :idempotent

        # @param client_id [String, nil] CDEK OAuth2 client id
        # @param client_secret [String, nil] CDEK OAuth2 client secret
        # @param sandbox [Boolean] use the CDEK sandbox environment
        def initialize(client_id: nil, client_secret: nil, sandbox: true, **)
          super()
          @client_id = client_id
          @client_secret = client_secret
          @sandbox = sandbox
        end
      end
    end
  end
end
