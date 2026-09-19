# frozen_string_literal: true

require "json"

RSpec.describe Yamshik::Cdek::V2::Adapter do
  subject(:adapter) { described_class.new(client_id: "id", client_secret: "secret", sandbox: true) }

  let(:parcel) { build_valid_parcel(reference: "ORD-42") }

  before do
    stub_request(:post, %r{api\.edu\.cdek\.ru/v2/oauth/token})
      .to_return(status: 200, body: { access_token: "token-123", expires_in: 3600 }.to_json,
                 headers: { "Content-Type" => "application/json" })
  end

  describe "#create_order" do
    before do
      stub_request(:post, "https://api.edu.cdek.ru/v2/orders")
        .to_return(status: 200,
                   body: { entity: { uuid: "72753031-1234-5678-9abc-def012345678" },
                           requests: [{ state: "ACCEPTED" }] }.to_json)
    end

    it "creates an order and returns the pending parcel with the carrier uuid" do
      result = adapter.create_order(parcel, carrier_options: { tariff_code: "136" })

      expect(result).to be_success
      value = result.value
      expect(value.external_id).to eq("72753031-1234-5678-9abc-def012345678")
      expect(value.carrier).to eq(:cdek)
      expect(value.registration_state).to eq(:pending)
    end

    it "maps the parcel into the CDEK payload" do
      adapter.create_order(parcel, carrier_options: { tariff_code: "136" })

      expect(WebMock).to have_requested(:post, "https://api.edu.cdek.ru/v2/orders") do |request|
        body = JSON.parse(request.body)
        body["number"] == "ORD-42" &&
          body["tariff_code"] == 136 &&
          body["delivery_point"] == "KZN1" &&
          body["from_location"] == { "city" => "Москва", "address" => "ул. Ленина, 1" } &&
          body["packages"][0]["weight"] == 500 &&
          body["packages"][0]["items"][0]["cost"].to_i == 1500
      end
    end

    it "sends the bearer token" do
      adapter.create_order(parcel, carrier_options: { tariff_code: "136" })

      expect(WebMock).to have_requested(:post, "https://api.edu.cdek.ru/v2/orders")
        .with(headers: { "Authorization" => "Bearer token-123" })
    end

    it "caches the token across calls" do
      adapter.create_order(parcel, carrier_options: { tariff_code: "136" })
      adapter.create_order(parcel, carrier_options: { tariff_code: "136" })

      expect(WebMock).to have_requested(:post, %r{api\.edu\.cdek\.ru/v2/oauth/token}).once
    end

    it "rejects unknown carrier_options keys without hitting the network" do
      result = adapter.create_order(parcel, carrier_options: { tariff_code: "136", bogus: 1 })

      expect(result).to be_failure
      expect(result.error.code).to eq(:validation_failed)
      expect(result.error.details[:path]).to eq("carrier_options")
    end

    it "requires tariff_code" do
      result = adapter.create_order(parcel)

      expect(result).to be_failure
      expect(result.error.code).to eq(:validation_failed)
    end

    it "requires at least one place" do
      parcel_without_places = Yamshik::Parcel.new(**parcel.to_h, places: [])

      result = adapter.create_order(parcel_without_places, carrier_options: { tariff_code: "136" })

      expect(result).to be_failure
      expect(result.error.code).to eq(:validation_failed)
    end

    context "when CDEK refuses the order" do
      it "maps validation errors to :validation_failed with the carrier code" do
        stub_request(:post, "https://api.edu.cdek.ru/v2/orders")
          .to_return(status: 400,
                     body: { errors: [{ code: "ERR_FIELD_INVALID", message: "Поле weight обязательно" }] }.to_json)

        result = adapter.create_order(parcel, carrier_options: { tariff_code: "136" })

        expect(result).to be_failure
        expect(result.error.code).to eq(:validation_failed)
        expect(result.error.carrier_code).to eq("ERR_FIELD_INVALID")
        expect(result.error.message).to eq("Поле weight обязательно")
      end

      it "maps duplicate order numbers to :duplicate" do
        stub_request(:post, "https://api.edu.cdek.ru/v2/orders")
          .to_return(status: 400,
                     body: { errors: [{ code: "ERR_ORDER_EXISTS",
                                        message: "Заказ с таким номером уже существует" }] }.to_json)

        result = adapter.create_order(parcel, carrier_options: { tariff_code: "136" })

        expect(result.error.code).to eq(:duplicate)
      end
    end
  end

  describe "#parcel" do
    let(:uuid) { "72753031-1234-5678-9abc-def012345678" }
    let(:request_state) { "ACCEPTED" }
    let(:order_body) do
      {
        entity: {
          uuid:, number: "ORD-42",
          sender: { name: "Иван Иванов", phones: [{ number: "+79990000000" }] },
          recipient: { name: "Пётр Петров", phones: [{ number: "+79990000001" }] },
          to_location: { city: "Казань" },
          delivery_point: "KZN1"
        },
        requests: [{ state: request_state }]
      }.to_json
    end

    before do
      stub_request(:get, "https://api.edu.cdek.ru/v2/orders/#{uuid}").to_return(status: 200, body: order_body)
    end

    context "when registration succeeded" do
      let(:request_state) { "SUCCESSFUL" }

      it "returns a registered parcel" do
        result = adapter.parcel(uuid)

        expect(result).to be_success
        expect(result.value.registration_state).to eq(:registered)
        expect(result.value.external_id).to eq(uuid)
        expect(result.value.reference).to eq("ORD-42")
        expect(result.value.destination.pickup_point_code).to eq("KZN1")
      end
    end

    context "when registration is still in flight" do
      it "returns a pending parcel" do
        expect(adapter.parcel(uuid).value.registration_state).to eq(:pending)
      end
    end

    context "when registration failed on the carrier side" do
      let(:request_state) { "INVALID" }

      it "returns a rejected parcel" do
        expect(adapter.parcel(uuid).value.registration_state).to eq(:rejected)
      end
    end

    context "when the order does not exist" do
      it "returns :not_found" do
        stub_request(:get, "https://api.edu.cdek.ru/v2/orders/missing")
          .to_return(status: 404, body: { errors: [{ code: "ERR_NOT_FOUND", message: "Not found" }] }.to_json)

        result = adapter.parcel("missing")

        expect(result).to be_failure
        expect(result.error.code).to eq(:not_found)
      end
    end
  end

  describe "authentication" do
    it "raises AuthenticationError on rejected credentials" do
      stub_request(:post, %r{api\.edu\.cdek\.ru/v2/oauth/token}).to_return(status: 401, body: "")

      expect { adapter.parcel("x") }.to raise_error(Yamshik::AuthenticationError)
    end
  end
end
