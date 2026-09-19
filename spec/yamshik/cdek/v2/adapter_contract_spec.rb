# frozen_string_literal: true

require "yamshik/spec/contract"

RSpec.describe Yamshik::Cdek::V2::Adapter do
  # The contract suite runs against WebMock stubs built from the CDEK API
  # docs examples. Once sandbox credentials are available, these stubs get
  # replaced by recorded VCR cassettes (yamshik#9).
  it_behaves_like "a yamshik carrier" do
    let(:carrier) { described_class.new(client_id: "id", client_secret: "secret", sandbox: true) }
    let(:valid_parcel) { build_valid_parcel }
    let(:carrier_options) { { tariff_code: "136" } }

    before do
      stub_request(:post, %r{api\.edu\.cdek\.ru/v2/oauth/token})
        .to_return(status: 200, body: { access_token: "token-123", expires_in: 3600 }.to_json)
      stub_request(:post, "https://api.edu.cdek.ru/v2/orders")
        .to_return(status: 200,
                   body: { entity: { uuid: "72753031-1234-5678-9abc-def012345678" },
                           requests: [{ state: "ACCEPTED" }] }.to_json)
      stub_request(:get, "https://api.edu.cdek.ru/v2/orders/72753031-1234-5678-9abc-def012345678")
        .to_return(status: 200,
                   body: { entity: { uuid: "72753031-1234-5678-9abc-def012345678", number: "TEST-1",
                                     sender: { name: "Иван Иванов", phones: [{ number: "+79990000000" }] },
                                     recipient: { name: "Пётр Петров", phones: [{ number: "+79990000001" }] },
                                     to_location: { city: "Казань" }, delivery_point: "KZN1" },
                           requests: [{ state: "SUCCESSFUL" }] }.to_json)
      stub_request(:get, "https://api.edu.cdek.ru/v2/orders/definitely-missing-id")
        .to_return(status: 404,
                   body: { errors: [{ code: "ERR_NOT_FOUND", message: "Not found" }] }.to_json)
    end
  end
end
