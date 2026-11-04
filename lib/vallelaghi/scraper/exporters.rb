# frozen_string_literal: true

require 'csv'
require 'fileutils'
require 'json'
require 'rss'

module Vallelaghi
  module Scraper
    ##
    # Writers for the scraped articles: JSON, CSV and RSS 2.0 feeds
    module Exporters
      ##
      # JSON export (also used as input to rebuild the feeds)
      module Json
        module_function

        def write(articles, path)
          FileUtils.mkdir_p(File.dirname(path))
          File.write(path, JSON.pretty_generate({ articles: articles.map(&:to_h) }))
          path
        end

        def read(path)
          JSON.parse(File.read(path)).fetch('articles').map { |hash| Article.from_h(hash) }
        end
      end

      ##
      # CSV export (the HTML body is left out)
      module Csv
        COLUMNS = (Article::ATTRIBUTES - [:html]).freeze

        module_function

        def write(articles, path)
          FileUtils.mkdir_p(File.dirname(path))
          CSV.open(path, 'w', write_headers: true, headers: COLUMNS) do |csv|
            articles.each { |article| csv << article.to_h.values_at(*COLUMNS) }
          end
          path
        end
      end

      ##
      # RSS 2.0 feeds: one with every article and one per section.
      #
      # The site published its own Joomla feeds, but they only contained the
      # latest few items and are gone together with the site, so the feeds are
      # rebuilt from the scraped articles. Item links point to the Wayback
      # Machine copy, since the original pages no longer exist.
      module Rss
        module_function

        # @param +articles+:: Array of Article
        # @param +dir+:: output directory
        # @param +max_items+:: maximum number of items per feed, +nil+ for no limit
        # @returns the Array of written paths
        def write(articles, dir, max_items: nil)
          FileUtils.mkdir_p(dir)
          feeds = { 'all' => articles }.merge(articles.group_by(&:section).reject { |section, _| section.nil? })
          feeds.map do |name, items|
            path = File.join(dir, "#{name}.xml")
            File.write(path, build(items, section: name == 'all' ? nil : name, max_items: max_items).to_s)
            path
          end
        end

        # Builds a single feed
        #
        # @returns an RSS::Rss object
        def build(articles, section: nil, max_items: nil)
          items = sort(articles)
          items = items.first(max_items) if max_items

          RSS::Maker.make('2.0') do |maker|
            fill_channel(maker.channel, section, items)
            items.each { |article| add_item(maker, article) }
          end
        end

        def sort(articles)
          articles.sort_by { |a| a.published_at || Time.at(0) }.reverse
        end

        def fill_channel(channel, section, items)
          name = section ? VallelaghiConstants.section_name(section) : 'Tutti gli articoli'
          url = section ? VallelaghiConstants.section_url(section) : VallelaghiConstants::SITE_URL
          channel.title = "valledeilaghi.it - #{name}"
          channel.link = Wayback.view_url(url)
          channel.description = "Archivio del quotidiano on-line valledeilaghi.it (#{name}), " \
                                'ricostruito dalla Wayback Machine'
          channel.language = 'it-IT'
          channel.generator = "vallelaghi-scraper #{VERSION}"
          channel.lastBuildDate = items.filter_map(&:published_at).max || Time.now
        end

        def add_item(maker, article)
          maker.items.new_item do |item|
            item.title = article.title.to_s
            item.link = article.archive_url || article.link
            item.guid.content = article.link
            item.guid.isPermaLink = true
            item.description = article.description || truncate(article.text)
            item.content_encoded = article.html if article.html
            item.pubDate = article.published_at if article.published_at
            item.dc_creator = article.author if article.author
            if article.section
              item.categories.new_category { |c| c.content = VallelaghiConstants.section_name(article.section) }
            end
          end
        end

        def truncate(text, length = 300)
          return '' if text.nil?

          text.length > length ? "#{text[0, length].sub(/\s+\S*\z/, '')}..." : text
        end
      end
    end
  end
end
