# frozen_string_literal: true

RSpec.describe Vallelaghi::Scraper::ListingParser do
  subject(:parser) { described_class.new(fixture('listing_articoli_di_valle.html'), section: 'articoli-di-valle') }

  let(:first) { parser.articles.first }

  it 'finds every article of the page' do
    expect(parser.articles.size).to eq(5)
  end

  it 'returns Article objects' do
    expect(parser.articles).to all(be_a(Vallelaghi::Scraper::Article))
  end

  it 'extracts title, absolute link, section and intro' do
    expect(first).to have_attributes(
      title: 'Incidente stradale e caduta massi - Sarche / Vigolo Baselga',
      link: 'http://www.valledeilaghi.it/jcms/20200926/articoli-di-valle/incidente-stradale-e-caduta-massi-sarche-vigolo-baselga',
      section: 'articoli-di-valle',
      description: 'Doppio intervento dei pompieri volontari.'
    )
  end

  it 'extracts author, date and image' do
    expect(first).to have_attributes(
      author: 'redazione',
      published_at: Time.iso8601('2020-09-26T11:11:12+02:00'),
      image_url: 'http://www.valledeilaghi.it/jcms/images/archivio/202009/26_massi/thumbnails/thumb_200926_massi_1.jpg'
    )
  end

  it 'finds the next page' do
    expect(parser.next_page_url).to eq('http://www.valledeilaghi.it/jcms/articoli/articoli-di-valle?start=5')
  end
end

RSpec.describe Vallelaghi::Scraper::ArticleParser do
  let(:new_url) do
    'http://www.valledeilaghi.it/jcms/20200926/articoli-di-valle/incidente-stradale-e-caduta-massi-sarche-vigolo-baselga'
  end
  let(:old_url) { 'http://www.valledeilaghi.it/jcms/201601086906/regionali/festival-del-benessere-mezzocorona.htm' }

  describe 'a 2020 article' do
    subject(:attributes) { described_class.new(fixture('article_2020.html'), url: new_url).attributes }

    it 'extracts the metadata' do
      expect(attributes).to include(
        title: 'Incidente stradale e caduta massi - Sarche / Vigolo Baselga',
        section: 'articoli-di-valle',
        author: 'redazione',
        published_at: Time.iso8601('2020-09-26T11:11:12+02:00'),
        description: 'Doppio intervento dei pompieri volontari.'
      )
    end

    it 'collects every paragraph, not just one' do
      expect(attributes[:text].split("\n\n")).to include(
        'Doppio intervento dei pompieri volontari.',
        a_string_starting_with('SARCHE / VIGOLO BASELGA – Questa mattina'),
        'foto di repertorio'
      )
    end

    it 'drops the social sharing widgets' do
      expect([attributes[:text], attributes[:html]]).to all(satisfy { |s| !s.match?(/facebook|twitter|whatsapp/i) })
    end
  end

  describe 'a 2016 article (old url scheme)' do
    subject(:attributes) { described_class.new(fixture('article_2016.html'), url: old_url).attributes }

    it 'extracts the metadata' do
      expect(attributes).to include(title: 'Festival del Benessere - Mezzocorona', section: 'regionali',
                                    author: 'Valeria Gelosa',
                                    published_at: Time.iso8601('2016-01-08T16:11:59+01:00'))
    end

    it 'extracts the text, intro included' do
      expect(attributes[:text].split("\n\n")).to include(
        a_string_starting_with('A gennaio 2016 torna l’appuntamento'),
        a_string_starting_with('MEZZOCORONA - Un appuntamento in programma il 16 e 17 gennaio 2016')
      )
    end
  end

  it 'rewrites image urls with the given lambda' do
    parser = described_class.new(fixture('article_2020.html'), url: new_url, rewrite_asset: ->(u) { "X#{u}" })
    expect(Nokogiri::HTML(parser.attributes[:html]).css('img').map { |i| i['src'] })
      .to all(start_with('Xhttp://www.valledeilaghi.it/jcms/images/'))
  end

  it 'recognizes pages without an article' do
    expect(described_class.new('<html><body><p>404</p></body></html>')).not_to be_article
  end

  it 'falls back to the whole body when there are no paragraphs' do
    html = '<article><section class="article-content"><div>solo <b>testo</b></div></section></article>'
    expect(described_class.new(html).attributes[:text]).to eq('solo testo')
  end
end
