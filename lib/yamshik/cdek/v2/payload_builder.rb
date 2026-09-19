# frozen_string_literal: true

module Yamshik
  module Cdek
    module V2
      # Builds the CDEK API v2 order creation payload from a Yamshik::Parcel.
      #
      # Mapping notes:
      # - Parcel#reference → +number+ (the idempotency anchor, DESIGN.md §3);
      # - a Point with pickup_point_code becomes +delivery_point+/+shipment_point+,
      #   a door Point becomes +to_location+/+from_location+ with city+address;
      # - Money (kopecks) → rubles floats; weights stay in grams (CDEK unit).
      module PayloadBuilder
        module_function

        # @param parcel [Yamshik::Parcel]
        # @param carrier_options [Hash] validated by the adapter (tariff_code etc.)
        # @return [Hash]
        def call(parcel, carrier_options)
          {
            number: parcel.reference,
            tariff_code: carrier_options[:tariff_code],
            comment: parcel.comment,
            developer_key: carrier_options[:developer_key],
            shipment_point: carrier_options[:shipment_point] || origin_point(parcel.origin),
            delivery_point: destination_point(parcel.destination),
            from_location: location(parcel.origin, door: true),
            to_location: location(parcel.destination, door: true),
            sender: contact(parcel.sender),
            recipient: contact(parcel.recipient),
            services: services(parcel.services),
            packages: packages(parcel.places)
          }.compact
        end

        # Pickup points are referenced by code; door points by location.
        def origin_point(point)
          point.type == :pickup_point ? point.pickup_point_code : nil
        end

        def destination_point(point)
          point.type == :pickup_point ? point.pickup_point_code : nil
        end

        def location(point, door:)
          return nil unless door && point.type == :door

          { city: point.city, address: point.address, postal_code: point.index }.compact
        end

        def contact(contact)
          company = contact.company
          {
            name: contact.name,
            company: company&.name,
            email: contact.email,
            phones: [{ number: contact.phone }]
          }.compact
        end

        def services(parcel_services)
          return nil if parcel_services.empty?

          parcel_services.map do |service|
            { code: service.carrier_code, parameter: rubles(service.amount) }.compact
          end
        end

        def packages(places)
          places.map.with_index(1) do |place, index|
            {
              number: index.to_s,
              weight: place.weight_g,
              length: place.length_cm,
              width: place.width_cm,
              height: place.height_cm,
              items: items(place)
            }.compact
          end
        end

        def items(place)
          return nil if place.place_items.empty?

          place.place_items.map do |place_item|
            item = place_item.item
            {
              name: item.name,
              ware_key: item.sku,
              cost: rubles(item.price),
              payment: { value: rubles(item.price) },
              weight: item.weight_g,
              amount: place_item.quantity
            }.compact
          end
        end

        # Money is kopecks Integer (DESIGN.md §6); CDEK wants rubles.
        def rubles(money)
          return nil unless money

          money.amount / 100.0
        end
      end
    end
  end
end
