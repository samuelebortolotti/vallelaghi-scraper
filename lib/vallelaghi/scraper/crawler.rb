# frozen_string_literal: true

require 'logger'

module Vallelaghi
  module Scraper
    ##
    # Recovers the articles of valledeilaghi.it from the Wayback Machine.
    #
    # Two strategies are available:
    #
    # * #latest: the newest archived listing page of each section, i.e. what the
    #   original scraper did when the site was online;
    # * #archive: every article ever archived, enumerated through the CDX index.
    class Crawler
      include VallelaghiConstants

      attr_reader :wayback

      # @param +http+:: HttpClient used for every request
      # @param +logger+:: a +Logger+ for progress messages
      def initialize(http: HttpClient.new, logger: Logger.new(nil))
        @wayback = Wayback.new(http)
        @logger = logger
      end

      # Articles listed in the newest archived page of each section
      #
      # @param +sections+:: Array of section slugs
      # @param +fetch_text+:: when +true+ every article page is downloaded to get the full text
      # @returns an Array of Article
      def latest(sections: SECTIONS.keys, fetch_text: true)
        sections.flat_map do |section|
          listing = section_listing(section)
          next [] unless listing

          @logger.info("#{VallelaghiConstants.section_name(section)}: #{listing[:articles].size} articles " \
                       "(snapshot #{listing[:capture].timestamp})")
          listing[:articles].each_with_index do |article, index|
            article.archive_url = Wayback.view_url(article.link, listing[:capture].timestamp)
            next unless fetch_text

            @logger.info("  [#{index + 1}/#{listing[:articles].size}] #{article.title}")
            # keep the data of the listing, but do not link to a page that was never archived
            article.archive_url = nil unless complete(article, timestamp: listing[:capture].timestamp)
          end
        end
      end

      # Every archived article
      #
      # @param +sections+:: Array of section slugs to keep, +nil+ for all of them
      # @param +from+:: Date, oldest publication date to keep
      # @param +to+:: Date, newest publication date to keep
      # @param +limit+:: maximum number of articles
      # @yield each Article as soon as it is retrieved (useful to save progress)
      # @returns an Array of Article, newest first
      def archive(sections: nil, from: nil, to: nil, limit: nil)
        @logger.info('Querying the Wayback Machine index...')
        index = ArchiveIndex.new(@wayback.captures(ARCHIVE_PREFIX, match_type: :prefix, collapse: :urlkey))
        entries = index.entries(sections: sections, from: from, to: to, limit: limit)
        @logger.info("#{index.size} archived articles found, #{entries.size} selected")

        entries.each_with_index.filter_map do |entry, i|
          @logger.info("[#{i + 1}/#{entries.size}] #{entry.date} #{entry.section} #{entry.slug}")
          article = Article.new(link: entry.link, section: entry.section, published_at: entry.date.to_time,
                                title: entry.slug.tr('-', ' ').capitalize)
          next unless complete(article, capture: entry.capture)

          yield(article) if block_given?
          article
        end
      end

      private

      def section_listing(section)
        url = VallelaghiConstants.section_url(section)
        capture = @wayback.latest_capture(url)
        unless capture
          @logger.warn("#{url} was never archived")
          return nil
        end

        page = @wayback.fetch(capture)
        { capture: page.capture, articles: ListingParser.new(page.body, section: section).articles }
      rescue HttpClient::Error => e
        @logger.error("Cannot retrieve #{url}: #{e.message}")
        nil
      end

      # Downloads the page of +article+ and fills in its text
      #
      # @returns +true+ on success, +false+ if the page is not available
      def complete(article, capture: nil, timestamp: Wayback::LATEST)
        page = capture ? @wayback.fetch(capture) : @wayback.fetch(article.link, timestamp: timestamp)
        ts = page.capture.timestamp
        parser = ArticleParser.new(page.body, url: article.link,
                                              rewrite_asset: ->(url) { Wayback.image_url(url, ts) })
        unless parser.article?
          @logger.warn("  no article found in #{page.capture.raw_url}")
          return false
        end

        article.merge!(parser.attributes)
        article.archive_url = Wayback.view_url(article.link, ts)
        true
      rescue HttpClient::Error => e
        @logger.warn("  skipped: #{e.message}")
        false
      end
    end
  end
end
