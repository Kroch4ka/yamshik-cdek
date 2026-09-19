# frozen_string_literal: true

require "json"

module Yamshik
  module Cdek
    module V2
      # Maps CDEK API v2 responses back to Yamshik::Parcel (DESIGN.md §4).
      #
      # CDEK registers orders asynchronously: a successful POST /orders returns
      # an entity uuid immediately, while the request state
      # (ACCEPTED → PROCESSING → SUCCESSFUL/INVALID) arrives later.
      module ParcelMapper
        module_function

        # Builds the result of create_order: the client's Parcel enriched with
        # the carrier uuid, still pending async registration.
        #
        # @param parcel [Yamshik::Parcel] the parcel as sent
        # @param response [Faraday::Response] successful POST /orders response
        # @return [Yamshik::Parcel]
        # @raise [Yamshik::InvalidResponseError] if the uuid is missing
        def from_creation(parcel, response)
          body = parse(response.body)
          uuid = body.dig("entity", "uuid")
          raise Yamshik::InvalidResponseError, "CDEK creation response misses entity.uuid" unless uuid

          Yamshik::Parcel.new(**parcel.to_h, external_id: uuid, carrier: :cdek,
                                             registration_state: :pending)
        end

        # Builds the result of parcel(external_id) — a registration refresh.
        # The Parcel is reconstructed from the CDEK order entity; the
        # registration state is derived from the request states.
        #
        # @param response [Faraday::Response] successful GET /orders/{uuid} response
        # @return [Yamshik::Parcel]
        def from_order(response)
          body = parse(response.body)
          entity = body.fetch("entity") { {} }
          requests = body.fetch("requests") { [] }

          Yamshik::Parcel.new(
            reference: entity["number"] || entity["uuid"],
            external_id: entity["uuid"],
            carrier: :cdek,
            registration_state: registration_state(requests),
            sender: contact(entity["sender"]),
            recipient: contact(entity["recipient"]),
            origin: point(entity["from_location"], entity["shipment_point"]),
            destination: point(entity["to_location"], entity["delivery_point"]),
            comment: entity["comment"]
          )
        end

        # CDEK request states: ACCEPTED/PROCESSING are in-flight,
        # SUCCESSFUL — registered, INVALID/FAILED — rejected.
        def registration_state(requests)
          states = requests.map { |request| request["state"] }
          return :pending if states.empty? || states.intersect?(%w[ACCEPTED PROCESSING])
          return :rejected if states.intersect?(%w[INVALID FAILED])
          return :registered if states.all? { |s| s == "SUCCESSFUL" }

          :pending
        end

        def contact(data)
          data ||= {}
          Yamshik::Contact.new(
            name: data["name"] || "—",
            phone: data.dig("phones", 0, "number") || "—",
            email: data["email"]
          )
        end

        def point(location, pickup_code)
          location ||= {}
          Yamshik::Point.new(
            city: location["city"] || "—",
            address: location["address"],
            index: location["postal_code"],
            pickup_point_code: pickup_code
          )
        end

        def parse(body)
          JSON.parse(body)
        rescue JSON::ParserError
          raise Yamshik::InvalidResponseError, "CDEK response is not valid JSON"
        end
      end
    end
  end
end
