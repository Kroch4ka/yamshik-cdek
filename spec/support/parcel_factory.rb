# frozen_string_literal: true

require "securerandom"

module ParcelFactory
  # Builds a minimal Parcel that any adapter should accept.
  def build_valid_parcel(reference: "TEST-#{SecureRandom.hex(4)}")
    Yamshik::Parcel.new(
      reference:,
      sender: Yamshik::Contact.new(name: "Иван Иванов", phone: "+79990000000"),
      recipient: Yamshik::Contact.new(name: "Пётр Петров", phone: "+79990000001"),
      origin: Yamshik::Point.new(city: "Москва", address: "ул. Ленина, 1"),
      destination: Yamshik::Point.new(city: "Казань", pickup_point_code: "KZN1")
    )
  end
end
