# frozen_string_literal: true

require 'uri'

module Vallelaghi
  module Scraper
    ##
    # Small helpers shared by the parsers
    module Util
      module_function

      # Collapses every run of whitespace (including non-breaking spaces) into a
      # single space and strips the result
      def squish(text)
        return nil if text.nil?

        text.to_s.gsub(/[[:space:]]+/, ' ').strip
      end

      # Resolves +href+ against +base+, returning +nil+ for blank or unusable links
      def absolute_url(href, base = VallelaghiConstants::BASE_URL)
        href = href.to_s.strip
        return nil if href.empty? || href.start_with?('#', 'javascript:', 'mailto:')

        URI.join(base, href.gsub(' ', '%20')).to_s
      rescue URI::Error
        nil
      end
    end
  end
end
