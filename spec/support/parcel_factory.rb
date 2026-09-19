# frozen_string_literal: true

require "securerandom"

module ParcelFactory
  # Builds a minimal Parcel that any adapter should accept.
  def build_valid_parcel(reference: "TEST-#{SecureRandom.hex(4)}")
    item = Yamshik::Item.new(name: "Футболка", sku: "TSH-1", quantity: 1,
                             price: Yamshik::Money.new(amount: 150_000), weight_g: 200)

    Yamshik::Parcel.new(
      reference:,
      sender: Yamshik::Contact.new(name: "Иван Иванов", phone: "+79990000000"),
      recipient: Yamshik::Contact.new(name: "Пётр Петров", phone: "+79990000001"),
      origin: Yamshik::Point.new(city: "Москва", address: "ул. Ленина, 1"),
      destination: Yamshik::Point.new(city: "Казань", pickup_point_code: "KZN1"),
      items: [item],
      places: [Yamshik::Place.new(weight_g: 500, length_cm: 30, width_cm: 20, height_cm: 10,
                                  place_items: [Yamshik::PlaceItem.new(item:, quantity: 1)])]
    )
  end
end
