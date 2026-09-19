# frozen_string_literal: true

require "json"

module Yamshik
  module Cdek
    module V2
      # Maps CDEK error responses to Yamshik::CarrierError (DESIGN.md §2).
      module ErrorMapper
        # CDEK reports duplicate order numbers as validation errors with
        # a recognizable message ("Заказ с таким номером уже существует").
        DUPLICATE_PATTERN = /уже существует|already exists|duplicate/i

        module_function

        # @param response [Faraday::Response] a business-level failure (4xx)
        # @return [Yamshik::CarrierError]
        def call(response)
          errors = errors_from(response.body)

          Yamshik::CarrierError.new(
            code: code_for(response.status, errors),
            carrier: :cdek,
            message: errors.first&.fetch("message", nil) || "CDEK responded #{response.status}",
            details: { errors: },
            raw: safe_parse(response.body),
            carrier_code: errors.first&.fetch("code", nil)
          )
        end

        def code_for(status, errors)
          case status
          when 400 then errors.any? { |e| e["message"] =~ DUPLICATE_PATTERN } ? :duplicate : :validation_failed
          when 404 then :not_found
          else :rejected
          end
        end

        def errors_from(body)
          parsed = safe_parse(body)
          return [] unless parsed.is_a?(Hash) && parsed["errors"].is_a?(Array)

          parsed["errors"]
        end

        def safe_parse(body)
          JSON.parse(body)
        rescue JSON::ParserError
          { "unparsed_body" => body }
        end
      end
    end
  end
end
