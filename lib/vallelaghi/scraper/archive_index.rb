# frozen_string_literal: true

require 'date'

module Vallelaghi
  module Scraper
    ##
    # Turns the raw list of archived URLs into a de-duplicated list of articles.
    #
    # Over the years the site used several URL schemes for the same article, e.g.
    #
    #   /jcms/201601086906/regionali/festival-del-benessere-mezzocorona.htm
    #   /jcms/index.php/20160108/regionali/festival-del-benessere-mezzocorona.html
    #   /jcms/20200926/articoli-di-valle/incidente-stradale-e-caduta-massi-sarche-vigolo-baselga
    #
    # so every url is reduced to a key made of the publication date and the slug.
    class ArchiveIndex
      # Path of an article: optional index.php, date (+ optional numeric id), optional section, slug
      ARTICLE_PATH = %r{
        /jcms/(?:index\.php/)?
        (?<date>(?:19|20)\d{6})(?<id>\d*)/
        (?:(?<section>[a-z][a-z0-9-]*)/)?
        (?<slug>[a-z0-9][a-z0-9-]*?)
        (?:\.html?)?/?
        (?:[?#].*)?\z
      }xi

      # An archived article
      Entry = Struct.new(:key, :date, :section, :slug, :capture, keyword_init: true) do
        # Original url, normalized (no port, no query string)
        def link
          capture.original.sub(%r{\Ahttps?://(?:www\.)?valledeilaghi\.it(?::80)?}i, VallelaghiConstants::BASE_URL)
                 .sub(/[?#].*\z/, '')
        end
      end

      # Parses an archived url
      #
      # @returns a Hash with +:key+, +:date+, +:section+, +:slug+, or +nil+ if +url+ is not an article
      def self.parse(url)
        match = ARTICLE_PATH.match(url.to_s)
        return nil unless match

        date = Date.strptime(match[:date], '%Y%m%d')
        slug = match[:slug].downcase
        { key: "#{match[:date]}/#{slug}", date: date, section: match[:section]&.downcase, slug: slug }
      rescue Date::Error
        nil
      end

      # @param +captures+:: Array of Wayback::Capture
      def initialize(captures)
        @entries = build(captures)
      end

      # Filtered articles, newest first
      #
      # @param +sections+:: Array of section slugs to keep, +nil+ for every section
      # @param +from+:: Date, oldest publication date to keep
      # @param +to+:: Date, newest publication date to keep
      # @param +limit+:: maximum number of entries
      def entries(sections: nil, from: nil, to: nil, limit: nil)
        list = @entries.select { |entry| keep?(entry, sections, from, to) }
        limit ? list.first(limit) : list
      end

      def size
        @entries.size
      end

      private

      def keep?(entry, sections, from, to)
        return false if sections && !sections.include?(entry.section)
        return false if from && entry.date < from

        to.nil? || entry.date <= to
      end

      # Groups the captures by article, then keeps the best capture of each one:
      # urls that carry the section first, then the most recent capture
      def build(captures)
        groups = captures.filter_map { |c| (info = self.class.parse(c.original)) && [info, c] }
                         .group_by { |info, _| info[:key] }
        groups.values.map { |group| best_entry(group) }.sort_by { |e| [e.date, e.key] }.reverse
      end

      def best_entry(group)
        info, capture = group.max_by { |i, c| [i[:section] ? 1 : 0, c.timestamp] }
        Entry.new(**info, capture: capture)
      end
    end
  end
end
