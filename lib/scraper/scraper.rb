# frozen_string_literal: true

require 'kimurai'
require_relative 'article'
require_relative 'vallelaghi_constants'

##
# This the Vallelaghi scraper, it aims to get some informations like articles' title, link and description
# Have a look at the framework @see {Github}[https://github.com/vifreefly/kimuraframework#kimurai]
class VallelaghiScraper < Kimurai::Base
  # Note that a Capybara::Session object called browser is already present

  include VallelaghiConstants

  attr_reader :articles, :start_urls

  @name = 'vallelaghi_scraper'  # name of the scraper
  @start_urls = [ARTICOLI_DI_VALLE, ARTICOLI_REGIONALI, ARTICOLI_NAZIONALI, ARTICOLI_EDITORIALI, LETTERE_AL_GIORNALE] # urls that will be processed
  @engine = :selenium_firefox # engine used for scaping

  def initialize 
    super
    @articles = []
  end

  # Default method for the scraper
  #
  # Params:
  # @param +response+:: +Nokogiri::HTML+ object which is obtained by an HTTP get request and then parsed
  # @param +url+:: url that must be processed
  # @param +data+:: data which is passed between the requests
  def parse(response, url:, data: {})
    response.xpath("//div[@class='blog']//article").each do |art|
      art_title, art_href, art_desc, art_img = articles_params art
      article_instance = Article.new(art_title, art_href, art_desc, art_img)
      @articles << article_instance
      request_to :parse_article, :url => art_href, :data => { :article => article_instance }
    end
    @articles
  end

  # Function that retrives from the first pages, in which the articles are listed,
  # the title, link, description, image if exists, description
  #
  # Params:
  # @param +article+:: the article html object parsed from the Nokogiri::HTML
  def articles_params(article)
    # They generally use absolute paths
    title_header = article.css('h2.article-title a')
    article_title = title_header.text.squish
    article_href = title_header.attr('href')
    article_href = "#{BASE_URL}#{article_href}" if !article_href.nil? && !article_href.to_s.match(/\Ahttp/)
    article_desc = article.css('section.article-intro').text.squish
    article_img = article.css('img').attr('src')
    article_img = "#{BASE_URL}#{article_img}" if !article_img.nil? && !article_img.to_s.match(/\Ahttp/)
    [article_title, article_href, article_desc, article_img]
  end
  
  # Function which save the articles retrieved in the specified format mode
  #
  # Params:
  # @param +name+:: name of the file
  # @param +format_mode+:: the supported formats are :json, :pretty_json, :jsonlines, :csv
  def save_retrieved_articles(name, format_mode)
    hash_array = { :articles => @articles.map(&:to_hash) }
    save_to name, hash_array, :format => format_mode, :position => false
  end

  # Function which set scraple the text from the given link and add it to the current parsed article
  # 
  # Params:
  # @param +response+:: +Nokogiri::HTML+ object which is obtained by an HTTP get request and then parsed
  # @param +url+:: url that must be processed
  # @param +data+:: data which is passed between the requests, must contain a value associated to the key :article
  def parse_article(response, url:, data: {})
    #TODO: throw exception if the data doesn't have a value associated to :article key
    # The article's text is usually in the third p, but can happen that it is in the second and even the first (unfortunately the text has no specific location)
    data[:article].text = if response.xpath("(//section[@class='article-content clearfix']//p)[3]").nil? 
                            response.xpath("(//section[@class='article-content clearfix']//p)[3]").text.squish
                          elsif response.xpath("(//section[@class='article-content clearfix']//p)[2]").nil?
                            response.xpath("(//section[@class='article-content clearfix']//p)[2]").text.squish
                          else
                            response.xpath("(//section[@class='article-content clearfix']//p)[1]").text.squish
                          end
  end

  # Just an utility function used to print the articles
  def print_retrieved_articles 
    puts 'Articles retrieved {'
    @articles.each do |art|
      puts art.to_s
    end
    puts '}'
  end
end

#VallelaghiScraper.crawl!