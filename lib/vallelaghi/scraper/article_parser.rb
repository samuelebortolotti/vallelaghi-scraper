# frozen_string_literal: true

require 'nokogiri'
require 'time'

module Vallelaghi
  module Scraper
    ##
    # Parses the page of a single article.
    #
    # The text of an article is not in a fixed paragraph (the original scraper
    # looked for the 1st, 2nd or 3rd +<p>+), so every paragraph of the article
    # body is collected, after removing the social-sharing widgets.
    class ArticleParser
      BODY_SELECTORS = ['section.article-content', '[itemprop="articleBody"]', 'div.item-page'].freeze

      # @param +html+:: HTML of the article page
      # @param +url+:: original url of the article, used to resolve relative links
      # @param +rewrite_asset+:: optional lambda applied to every absolute image url
      #                          (used to point images to their archived copy)
      def initialize(html, url: VallelaghiConstants::BASE_URL, rewrite_asset: nil)
        @doc = html.is_a?(Nokogiri::HTML::Document) ? html : Nokogiri::HTML(html, nil, 'UTF-8')
        @url = url
        @cleaner = HtmlCleaner.new(url: url, rewrite_asset: rewrite_asset)
      end

      # @returns a Hash with the attributes of the article found in the page
      def attributes
        body = clean_body
        {
          title: title,
          section: section,
          author: Util.squish(article_node.at_css('[itemprop="author"] [itemprop="name"]')&.text),
          published_at: published_at,
          description: description,
          image_url: image_url(body),
          text: @cleaner.text(body),
          html: @cleaner.html(body)
        }
      end

      # Whether the page really contains an article
      def article?
        !@doc.at_css(BODY_SELECTORS.join(', ')).nil?
      end

      private

      def article_node
        @article_node ||= @doc.at_css('article') || @doc
      end

      def title
        heading = article_node.at_css('.article-title, [itemprop="name"], [itemprop="headline"]')
        Util.squish(heading&.text).then { |t| t.nil? || t.empty? ? meta('og:title') : t }
      end

      def section
        @url.to_s[ArchiveIndex::ARTICLE_PATH, :section]
      end

      def published_at
        value = article_node.at_css('time[datetime]')&.[]('datetime') ||
                @doc.at_css('meta[itemprop="datePublished"], meta[itemprop="dateCreated"]')&.[]('content')
        return Time.iso8601(value) if value

        date = @url.to_s[ArchiveIndex::ARTICLE_PATH, :date]
        date && Time.strptime(date, '%Y%m%d')
      rescue ArgumentError
        nil
      end

      def description
        value = Util.squish(meta('og:description'))
        value.nil? || value.empty? ? nil : value
      end

      def image_url(body)
        src = meta('og:image') || body&.at_css('img')&.[]('src')
        Util.absolute_url(src, @url)
      end

      def meta(name)
        @doc.at_css(%(meta[name="#{name}"], meta[property="#{name}"]))&.[]('content')
      end

      # Copy of the article body without scripts/social widgets and with absolute links
      def clean_body
        node = BODY_SELECTORS.lazy.filter_map do |selector|
          article_node.at_css(selector) || @doc.at_css(selector)
        end.first
        @cleaner.clean(node)
      end
    end
  end
end
