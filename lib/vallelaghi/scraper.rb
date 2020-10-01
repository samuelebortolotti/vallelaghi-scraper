# frozen_string_literal: true

require 'vallelaghi/scraper/version'
require 'vallelaghi/scraper/vallelaghi_constants'
require 'vallelaghi/scraper/base_scraper'
require 'vallelaghi/scraper/article/article'

module Vallelaghi
  module Scraper
    class Error < StandardError; end
  end
end

# Vallelaghi::Scraper::BaseScraper.crawl!
