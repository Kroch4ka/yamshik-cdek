# frozen_string_literal: true

require "yamshik"

require_relative "cdek/version"
require_relative "cdek/v2/adapter"

# CDEK (СДЭК) adapter for the yamshik core gem.
module Yamshik
  module Cdek
  end

  register_adapter(:cdek, Cdek::V2::Adapter)
end
