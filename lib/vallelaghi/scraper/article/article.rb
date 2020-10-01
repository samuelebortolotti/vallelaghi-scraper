module Vallelaghi
  module Scraper
    ##
    # This class represents an article written on the Vallelaghi.it site
    class Article
      attr_reader :title, :link, :description, :img_src
      attr_accessor :text

      # Creates a new article
      #
      # It initializes the title, the link and the description field, which are
      # readable using the getter methods.
      #
      # @param +title+:: title of the article
      # @param +link+:: link to the article
      # @param +description+:: description of the article
      # @param +img_src+:: link of the image related to the article, +nil+ if it does not exists
      def initialize(title, link, description, img_src, text = nil)
        @title = title
        @link = link
        @description = description
        @img_src = img_src
        @text = text unless text.nil?
      end

      # Article to String
      #
      # @returns Article's object rappresentation as a string
      def to_s
        to_rtn = "Article: \n title: #{title} \n link: #{link} \n description: #{description} \n"
        to_rtn << "img src: #{img_src} \n text: #{text}"
        to_rtn
      end

      # Article to hash
      #
      # @returns Article's object as hash
      def to_hash
        hash = {}
        instance_variables.each do |var|
          hash[var.to_s.delete('@').to_sym] = instance_variable_get(var).to_s
        end
        hash
      end
    end
  end
end
