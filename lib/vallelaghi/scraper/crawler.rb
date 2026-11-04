# frozen_string_literal: true

require 'logger'

module Vallelaghi
  module Scraper
    ##
    # Recovers the articles of valledeilaghi.it.
    #
    # By default pages come from the Wayback Machine (the site is offline);
    # pass +source: :live+ to read them from the site itself.
    #
    # Two strategies are available:
    #
    # * #latest: the newest listing page of each section, i.e. what the
    #   original scraper did when the site was online;
    # * #archive: every article ever archived, enumerated through the CDX index
    #   (Wayback Machine only).
    class Crawler
      include VallelaghiConstants

      # Where pages can be read from
      SOURCES = %i[wayback live].freeze

      attr_reader :source

      # @param +http+:: HttpClient used for every request
      # @param +source+:: +:wayback+ (default) or +:live+
      # @param +logger+:: a +Logger+ for progress messages
      def initialize(http: HttpClient.new, source: :wayback, logger: Logger.new(nil))
        raise ArgumentError, "unknown source '#{source}' (use #{SOURCES.join(' or ')})" unless SOURCES.include?(source)

        @source = source == :live ? LiveSite.new(http) : Wayback.new(http)
        @logger = logger
      end

      # Articles listed in the newest page of each section
      #
      # @param +sections+:: Array of section slugs
      # @param +fetch_text+:: when +true+ every article page is downloaded to get the full text
      # @param +limit+:: maximum number of articles per section
      # @returns an Array of Article
      def latest(sections: SECTIONS.keys, fetch_text: true, limit: nil)
        sections.flat_map { |section| latest_of(section, fetch_text: fetch_text, limit: limit) }
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
        raise Error, 'only the Wayback Machine can list old articles (use --source wayback)' if @source.is_a?(LiveSite)

        @logger.info('Querying the Wayback Machine index...')
        index = ArchiveIndex.new(@source.captures(ARCHIVE_PREFIX, match_type: :prefix, collapse: :urlkey))
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

      def latest_of(section, fetch_text:, limit:)
        listing = section_listing(section)
        return [] unless listing

        articles = listing[:articles].first(limit || listing[:articles].size)
        timestamp = listing[:capture].timestamp
        log_listing(section, articles, timestamp)
        articles.each_with_index do |article, index|
          article.archive_url = @source.view_url(article.link, timestamp)
          next unless fetch_text

          @logger.info("  [#{index + 1}/#{articles.size}] #{article.title}")
          # keep the data of the listing, but do not link to a page that was never archived
          article.archive_url = nil unless complete(article, timestamp: timestamp || Wayback::LATEST)
        end
      end

      def log_listing(section, articles, timestamp)
        origin = timestamp ? "snapshot #{timestamp}" : 'live site'
        @logger.info("#{VallelaghiConstants.section_name(section)}: #{articles.size} articles (#{origin})")
      end

      def section_listing(section)
        url = VallelaghiConstants.section_url(section)
        capture = @source.latest_capture(url)
        unless capture
          @logger.warn("#{url} was never archived")
          return nil
        end

        page = @source.fetch(capture)
        ts = page.capture.timestamp
        parser = ListingParser.new(page.body, section: section, rewrite_asset: ->(u) { @source.asset_url(u, ts) })
        { capture: page.capture, articles: parser.articles }
      rescue HttpClient::Error => e
        @logger.error("Cannot retrieve #{url}: #{e.message}")
        nil
      end

      # Downloads the page of +article+ and fills in its text
      #
      # @returns +true+ on success, +false+ if the page is not available
      def complete(article, capture: nil, timestamp: Wayback::LATEST)
        page = capture ? @source.fetch(capture) : @source.fetch(article.link, timestamp: timestamp)
        ts = page.capture.timestamp
        parser = ArticleParser.new(page.body, url: article.link,
                                              rewrite_asset: ->(url) { @source.asset_url(url, ts) })
        unless parser.article?
          @logger.warn("  no article found in #{page.capture.original}")
          return false
        end

        article.merge!(parser.attributes)
        article.archive_url = @source.view_url(article.link, ts)
        true
      rescue HttpClient::Error => e
        @logger.warn("  skipped: #{e.message}")
        false
      end
    end
  end
end
