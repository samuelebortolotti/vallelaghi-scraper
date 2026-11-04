# frozen_string_literal: true

require 'nokogiri'
require 'time'

module Vallelaghi
  module Scraper
    ##
    # Parses a section listing page (Joomla "blog" layout) into Article objects
    class ListingParser
      # @param +html+:: HTML of the listing page
      # @param +section+:: slug of the section the page belongs to
      # @param +base_url+:: url used to resolve relative links
      def initialize(html, section: nil, base_url: VallelaghiConstants::BASE_URL)
        @doc = html.is_a?(Nokogiri::HTML::Document) ? html : Nokogiri::HTML(html, nil, 'UTF-8')
        @section = section
        @base_url = base_url
      end

      # @returns an Array of Article, one for each article listed in the page
      def articles
        @doc.css('div.blog article').filter_map { |node| parse_article(node) }
      end

      # Url of the next listing page, +nil+ on the last page
      def next_page_url
        href = @doc.at_css('.pagination a[title="Avanti"]')&.[]('href')
        Util.absolute_url(href, @base_url)
      end

      private

      def parse_article(node)
        link_node = node.at_css('.article-title a')
        return nil unless link_node

        intro = node.at_css('section.article-intro')
        Article.new(
          title: Util.squish(link_node.text),
          link: Util.absolute_url(link_node['href'], @base_url),
          section: @section,
          author: Util.squish(node.at_css('[itemprop="author"] [itemprop="name"]')&.text),
          published_at: parse_time(node.at_css('time[datetime]')&.[]('datetime')),
          description: Util.squish(intro&.text),
          image_url: Util.absolute_url(intro&.at_css('img')&.[]('src'), @base_url)
        )
      end

      def parse_time(value)
        value && Time.iso8601(value)
      rescue ArgumentError
        nil
      end
    end
  end
end
