# frozen_string_literal: true

RSpec.describe Yamshik::Cdek do
  it "has a version number" do
    expect(Yamshik::Cdek::VERSION).not_to be_nil
  end

  it "registers itself as :cdek" do
    expect(Yamshik.carrier(:cdek)).to be_a(Yamshik::Cdek::V2::Adapter)
  end
end
