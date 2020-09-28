# frozen_string_literal: true

require 'kimurai'
require_relative 'article'

##
# This the Vallelaghi scraper, it aims to get some informations like articles' title, link and description
# Have a look at the framework @see {Github}[https://github.com/vifreefly/kimuraframework#kimurai]
class VallelaghiScraper < Kimurai::Base
  # Note that a Capybara::Session object called browser is already present

  attr_reader :articles, :start_urls, :base_url

  @name = 'vallelaghi_scraper'  # name of the scraper
  @start_urls = ['http://www.valledeilaghi.it/jcms/articoli/articoli-di-valle', 'http://www.valledeilaghi.it/jcms/articoli/regionali', 'http://www.valledeilaghi.it/jcms/articoli/nazionali-ed-estero', 'http://www.valledeilaghi.it/jcms/articoli/editoriali', 'http://www.valledeilaghi.it/jcms/articoli/lettere-al-giornale'] # urls that will be processed
  @engine = :selenium_firefox # engine used for scaping
  BASE_URL = 'http://www.valledeilaghi.it' # base url

  def initialize 
    super
    @articles = []
  end

  # Default method for the scraper
  #
  # Params:
  # +response+:: +Nokogiri::HTML+ object which is obtained by an HTTP get request and then parsed
  # +url+:: url that must be processed
  # +data+:: data which is passed between the requests
  def parse(response, url:, data: {})
    response.xpath("//div[@class='blog']//article").each do |art|
      title_header = art.css('h2.article-title a')
      art_title = title_header.text.squish
      art_href = title_header.attr('href')
      art_desc = art.css('h2.article-intro clearfix p').text.squish
      @articles << Article.new(art_title, art_href, art_desc)
    end
    
    @articles
  end
end

#VallelaghiScraper.crawl!
