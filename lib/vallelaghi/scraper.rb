# frozen_string_literal: true

module Vallelaghi
  ##
  # Scraper for the (now defunct) valledeilaghi.it online newspaper, which
  # recovers its articles from the Wayback Machine
  module Scraper
    # Base class of every error raised by the gem
    class Error < StandardError; end
  end
end

require 'vallelaghi/scraper/version'
require 'vallelaghi/scraper/vallelaghi_constants'
require 'vallelaghi/scraper/util'
require 'vallelaghi/scraper/article/article'
require 'vallelaghi/scraper/http_client'
require 'vallelaghi/scraper/wayback'
require 'vallelaghi/scraper/live_site'
require 'vallelaghi/scraper/archive_index'
require 'vallelaghi/scraper/listing_parser'
require 'vallelaghi/scraper/article_parser'
require 'vallelaghi/scraper/crawler'
require 'vallelaghi/scraper/exporters'
require 'vallelaghi/scraper/cli'
