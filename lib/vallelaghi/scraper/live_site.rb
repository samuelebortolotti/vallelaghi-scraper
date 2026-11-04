# frozen_string_literal: true

module Vallelaghi
  module Scraper
    ##
    # Reads pages straight from valledeilaghi.it instead of the Wayback Machine.
    #
    # It exposes the same interface as Wayback, so the Crawler can use either.
    # The site is offline at the moment: this source is only useful if it ever
    # comes back. It cannot enumerate old articles, so only +latest+ works.
    class LiveSite
      def initialize(http)
        @http = http
      end

      # The "capture" of a live page is the page itself (no timestamp)
      def latest_capture(url)
        Wayback::Capture.new(nil, url)
      end

      def fetch(capture, timestamp: nil) # rubocop:disable Lint/UnusedMethodArgument
        url = capture.is_a?(Wayback::Capture) ? capture.original : capture
        response = @http.get(url)
        Wayback::Page.new(response.body, Wayback::Capture.new(nil, response.url))
      end

      def captures(*)
        raise Error, 'the live site cannot list old articles: use the Wayback Machine (--source wayback)'
      end

      # Live pages have no archived copy
      def view_url(_url, _timestamp) = nil

      # Images are served by the site itself
      def asset_url(url, _timestamp) = url
    end
  end
end
