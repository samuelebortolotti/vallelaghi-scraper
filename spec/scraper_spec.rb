require_relative '../lib/scraper/article'
require_relative '../lib/scraper/scraper'
require 'httparty'
require 'nokogiri'

RSpec.describe VallelaghiScraper do
  subject(:vallelaghi_scraper) { described_class.new }

  let(:base_url) { 'http://www.valledeilaghi.it/jcms/' }

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

  context 'when the html page is requested' do
    it 'checks if the service is available: response code' do
      response = HTTParty.get(base_url)
      expect(response.code).to be_equal 200
    end
  end

  context 'when parse is called' do
    test_articles_gathering 'http://www.valledeilaghi.it/jcms/articoli/articoli-di-valle'

    test_articles_gathering 'http://www.valledeilaghi.it/jcms/articoli/regionali'

    test_articles_gathering 'http://www.valledeilaghi.it/jcms/articoli/nazionali-ed-estero'

    test_articles_gathering 'http://www.valledeilaghi.it/jcms/articoli/editoriali'

    test_articles_gathering 'http://www.valledeilaghi.it/jcms/articoli/lettere-al-giornale'
  end
end
