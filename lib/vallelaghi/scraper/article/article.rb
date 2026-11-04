# frozen_string_literal: true

require 'time'

module Vallelaghi
  module Scraper
    ##
    # This class represents an article written on the Vallelaghi.it site
    class Article
      # Every attribute of an article, in export order
      ATTRIBUTES = %i[title link archive_url section author published_at description image_url text html].freeze

      attr_accessor(*ATTRIBUTES)

      # Creates a new article
      #
      # @param +title+:: title of the article
      # @param +link+:: original link to the article on valledeilaghi.it
      # @param +archive_url+:: link to the Wayback Machine copy of the article
      # @param +section+:: slug of the newspaper section (e.g. +articoli-di-valle+)
      # @param +author+:: author of the article
      # @param +published_at+:: +Time+ of publication
      # @param +description+:: short introduction of the article
      # @param +image_url+:: link of the image related to the article, +nil+ if it does not exist
      # @param +text+:: plain text of the article
      # @param +html+:: cleaned HTML body of the article
      def initialize(**attributes)
        unknown = attributes.keys - ATTRIBUTES
        raise ArgumentError, "unknown attributes: #{unknown.join(', ')}" unless unknown.empty?

        attributes.each { |name, value| public_send("#{name}=", value) }
      end

      # Builds an article from a hash (e.g. one read back from a JSON export)
      def self.from_h(hash)
        attrs = hash.transform_keys(&:to_sym).slice(*ATTRIBUTES)
        attrs[:published_at] = Time.iso8601(attrs[:published_at]) if attrs[:published_at].is_a?(String)
        new(**attrs)
      end

      # Copies every non-nil attribute of +other+ (an Article or a Hash) into this article
      def merge!(other)
        other.to_h.each do |name, value|
          next unless ATTRIBUTES.include?(name.to_sym)
          next if value.nil? || (value.respond_to?(:empty?) && value.empty?)

          public_send("#{name}=", value)
        end
        self
      end

      # Article to String
      #
      # @returns Article's object representation as a string
      def to_s
        "Article:\n title: #{title}\n link: #{link}\n section: #{section}\n date: #{published_at}\n " \
          "description: #{description}\n img src: #{image_url}\n text: #{text}"
      end

      # Article to hash, with the publication date serialized as ISO 8601
      #
      # @returns Article's object as hash
      def to_h
        ATTRIBUTES.to_h do |name|
          value = public_send(name)
          value = value.iso8601 if value.respond_to?(:iso8601)
          [name, value]
        end
      end
    end
  end
end
