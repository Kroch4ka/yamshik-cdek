# frozen_string_literal: true

require "yamshik/spec/contract"

RSpec.describe Yamshik::Cdek::V2::Adapter do
  # The contract suite runs against recorded VCR cassettes once the adapter
  # is implemented (https://github.com/Kroch4ka/yamshik/issues/8).
  it_behaves_like "a yamshik carrier" do
    before { skip "adapter not implemented yet (yamshik#8)" }

    let(:carrier) { described_class.new }
    let(:valid_parcel) { build_valid_parcel }
  end
end
