# frozen_string_literal: true

require_relative '../lib/scraper/article'
require_relative '../lib/scraper/scraper'
require_relative '../lib/scraper/vallelaghi_constants'
require 'httparty'
require 'nokogiri'

RSpec.describe VallelaghiScraper do
  subject(:vallelaghi_scraper) { described_class.new }

  # Tests if the data gathered from the url is really an Article object
  #
  # @param +from_url+::url from which the data will be gathered
  def self.test_articles_gathering(from_url)
    it "retrieves articles from #{from_url} correctly" do
      html_page = HTTParty.get(from_url)
      articles = vallelaghi_scraper.parse Nokogiri::HTML(html_page.body), :url => from_url, :data => {}
      expect(articles).to all(be_a Article)
    end
  end

  # Tests the file which is generated
  #
  # @param +filename+::name of the file which will be saved
  # @param +mode+::the supported formats are :json, :pretty_json, :jsonlines, :csv
  def self.generate_check_existence_of_the_file(filename, mode)
    it "exists a file named #{filename}" do
      vallelaghi_scraper.save_retrieved_articles articles, filename, mode
      expect(File.file?(filename)).to be true
    end
  end

  context 'when the html page is requested' do
    it 'checks if the service is available: response code' do
      response = HTTParty.get(VallelaghiConstants::BASE_URL)
      expect(response.code).to be_equal 200
    end
  end

  describe '#parse' do
    test_articles_gathering VallelaghiConstants::ARTICOLI_DI_VALLE
    test_articles_gathering VallelaghiConstants::ARTICOLI_REGIONALI
    test_articles_gathering VallelaghiConstants::ARTICOLI_NAZIONALI
    test_articles_gathering VallelaghiConstants::ARTICOLI_EDITORIALI
    test_articles_gathering VallelaghiConstants::LETTERE_AL_GIORNALE
  end

  describe '#save_retrieved_articles' do
    let(:output_file) { 'scraped_articles' }
    
    generate_check_existence_of_the_file "#{output_file}.csv", :csv
    generate_check_existence_of_the_file "#{output_file}.json", :json
  end
end
