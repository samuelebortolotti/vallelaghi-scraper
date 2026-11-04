# frozen_string_literal: true

require 'json'
require 'uri'

module Vallelaghi
  module Scraper
    ##
    # Thin wrapper around the Internet Archive's Wayback Machine.
    #
    # * the CDX API (https://github.com/internetarchive/wayback/tree/master/wayback-cdx-server)
    #   lists the captures of a URL (or of every URL with a given prefix);
    # * the +id_+ replay mode returns a capture exactly as it was crawled, without
    #   the Wayback toolbar and without rewritten links.
    class Wayback
      CDX_URL = 'https://web.archive.org/cdx/search/cdx'
      WEB_URL = 'https://web.archive.org/web'
      # A timestamp in the far future: the Wayback Machine redirects it to the latest capture
      LATEST = '29991231235959'

      # A single capture of +original+ taken at +timestamp+ (YYYYMMDDhhmmss)
      Capture = Struct.new(:timestamp, :original) do
        def raw_url = Wayback.raw_url(original, timestamp)
        def view_url = Wayback.view_url(original, timestamp)
      end

      # A fetched capture: the page body plus the capture it really came from
      Page = Struct.new(:body, :capture)

      # Url returning the raw archived content
      def self.raw_url(original, timestamp = LATEST)
        "#{WEB_URL}/#{timestamp}id_/#{original}"
      end

      # Url to browse the archived page (with the Wayback toolbar)
      def self.view_url(original, timestamp = LATEST)
        "#{WEB_URL}/#{timestamp}/#{original}"
      end

      # Url serving an archived image
      def self.image_url(original, timestamp = LATEST)
        "#{WEB_URL}/#{timestamp}im_/#{original}"
      end

      # Extracts the capture from a Wayback url, +nil+ if +url+ is not a Wayback url
      def self.parse_url(url)
        match = %r{\Ahttps?://web\.archive\.org/web/(\d{1,14})[a-z_]*/(.+)\z}.match(url.to_s)
        match && Capture.new(match[1], match[2])
      end

      # @param +http+:: an HttpClient
      def initialize(http)
        @http = http
      end

      # Url to browse the archived copy of +url+ (same interface as LiveSite)
      def view_url(url, timestamp) = Wayback.view_url(url, timestamp)

      # Url of the archived copy of an image (same interface as LiveSite)
      def asset_url(url, timestamp) = Wayback.image_url(url, timestamp)

      # Lists the successful HTML captures of +url+
      #
      # @param +url+:: url (or url prefix when +match_type+ is +:prefix+)
      # @param +match_type+:: +nil+ for an exact match, +:prefix+ to match every url starting with +url+
      # @param +collapse+:: CDX collapse field (e.g. +urlkey+ to keep one capture per url)
      # @returns an Array of Capture
      def captures(url, match_type: nil, collapse: nil)
        params = [['url', url], %w[output json], %w[fl timestamp,original],
                  %w[filter statuscode:200], %w[filter mimetype:text/html]]
        params << ['matchType', match_type.to_s] if match_type
        params << ['collapse', collapse.to_s] if collapse
        body = @http.get("#{CDX_URL}?#{URI.encode_www_form(params)}").body.strip
        return [] if body.empty?

        rows = JSON.parse(body)
        rows.shift # header
        rows.map { |timestamp, original| Capture.new(timestamp, original) }
      rescue JSON::ParserError => e
        raise Error, "Unexpected CDX answer for #{url}: #{e.message}"
      end

      # The most recent successful capture of +url+, +nil+ if it was never archived
      def latest_capture(url)
        captures(url).max_by(&:timestamp)
      end

      # Downloads a capture.
      #
      # When +capture+ is a url, the capture closest to +timestamp+ is fetched
      # (the Wayback Machine redirects to it).
      #
      # @returns a Page
      def fetch(capture, timestamp: LATEST)
        capture = Capture.new(timestamp, capture) unless capture.is_a?(Capture)
        response = @http.get(capture.raw_url)
        Page.new(response.body, Wayback.parse_url(response.url) || capture)
      end
    end
  end
end
