# frozen_string_literal: true

require 'nokogiri'

module Vallelaghi
  module Scraper
    ##
    # Cleans a fragment of an article (the full body or the intro shown in a
    # listing page) and extracts its text
    class HtmlCleaner
      # Elements that never belong to the text of an article
      NOISE_SELECTORS = [
        'script', 'style', 'noscript', 'iframe', 'form',
        '[class*="fastsocialshare"]', '[class*="sh404sef"]', '[class*="social"]'
      ].freeze
      TEXT_SELECTORS = 'p, h1, h2, h3, h4, h5, h6, li, blockquote, pre'
      IMAGE = /\.(jpe?g|png|gif)\z/i

      # @param +url+:: url of the page, used to resolve relative links
      # @param +rewrite_asset+:: optional lambda applied to every absolute image url
      #                          (used to point images to their archived copy)
      def initialize(url: VallelaghiConstants::BASE_URL, rewrite_asset: nil)
        @url = url
        @rewrite_asset = rewrite_asset
      end

      # Copy of +node+ without scripts/social widgets and with absolute links
      def clean(node)
        return nil unless node

        node = node.dup
        node.css(NOISE_SELECTORS.join(', ')).each(&:remove)
        node.xpath('.//comment()').each(&:remove)
        absolutize(node)
        node
      end

      # Inner HTML of a cleaned node, +nil+ if blank
      def html(node)
        value = node&.inner_html&.strip
        value.nil? || value.empty? ? nil : value
      end

      # Plain text of a cleaned node: one paragraph per block, separated by a blank line
      def text(node)
        return nil unless node

        paragraphs = top_level_blocks(node).map { |n| Util.squish(n.text) }.reject(&:empty?)
        paragraphs = [Util.squish(node.text)] if paragraphs.empty?
        value = paragraphs.join("\n\n")
        value.empty? ? nil : value
      end

      # Absolute url of an image, rewritten with +rewrite_asset+
      def asset_url(src)
        url = Util.absolute_url(src, @url)
        url && @rewrite_asset ? @rewrite_asset.call(url) : url
      end

      private

      # Text blocks not nested in other blocks (e.g. a <p> inside a <li>), to avoid duplicated text
      def top_level_blocks(node)
        candidates = node.css(TEXT_SELECTORS).to_a
        ids = candidates.to_set(&:pointer_id)
        candidates.reject { |n| n.ancestors.any? { |a| ids.include?(a.pointer_id) } }
      end

      def absolutize(node)
        node.css('a[href]').each { |a| a['href'] = Util.absolute_url(a['href'], @url) || a['href'] }
        node.css('img[src]').each { |img| img['src'] = asset_url(img['src']) || img['src'] }
        # links that open the full size picture
        node.css('a.jcepopup[href]').each { |a| a['href'] = asset_url(a['href']) if a['href'].match?(IMAGE) }
      end
    end
  end
end
