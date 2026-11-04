# frozen_string_literal: true

RSpec.describe Vallelaghi::Scraper::Crawler do
  subject(:crawler) { described_class.new(http: Vallelaghi::Scraper::HttpClient.new(delay: 0, retries: 0)) }

  let(:wayback) { Vallelaghi::Scraper::Wayback }
  let(:listing_url) { Vallelaghi::Scraper::VallelaghiConstants::ARTICOLI_DI_VALLE }
  let(:listing_ts) { '20200926142122' }
  let(:article_ts) { '20201026185205' }
  let(:article_url) do
    'http://www.valledeilaghi.it/jcms/20200926/articoli-di-valle/incidente-stradale-e-caduta-massi-sarche-vigolo-baselga'
  end

  before do
    # the other pages of the archive were never captured
    stub_request(:get, %r{\Ahttps://web\.archive\.org/web/}).to_return(status: 404)
  end

  describe '#latest' do
    before do
      stub_request(:get, %r{/cdx/search/cdx}).with(query: hash_including('url' => listing_url))
                                             .to_return(body: [%w[timestamp original],
                                                               [listing_ts, listing_url]].to_json)
      stub_request(:get,
                   wayback.raw_url(listing_url, listing_ts)).to_return(body: fixture('listing_articoli_di_valle.html'))
      stub_request(:get, wayback.raw_url(article_url, listing_ts))
        .to_return(status: 302, headers: { 'Location' => wayback.raw_url(article_url, article_ts) })
      stub_request(:get, wayback.raw_url(article_url, article_ts)).to_return(body: fixture('article_2020.html'))
    end

    let(:articles) { crawler.latest(sections: ['articoli-di-valle']) }

    it 'returns the articles of the listing page' do
      expect(articles.size).to eq(5)
    end

    it 'downloads the text of the archived articles' do
      expect(articles.first).to have_attributes(
        text: a_string_including('SARCHE / VIGOLO BASELGA'),
        archive_url: wayback.view_url(article_url, article_ts)
      )
    end

    it 'keeps the listing data of the articles that were never archived' do
      expect(articles.drop(1)).to all(have_attributes(archive_url: nil, title: a_kind_of(String)))
    end

    it 'uses the intro as text and html of the articles that were never archived' do
      expect(articles.drop(1)).to all(have_attributes(text: a_kind_of(String), html: a_string_including('<')))
    end

    it 'points the images of the intro to the archive' do
      expect(articles[1].html).to include("https://web.archive.org/web/#{listing_ts}im_/http://www.valledeilaghi.it/")
    end

    it 'can skip the article pages, keeping the intro' do
      intros = crawler.latest(sections: ['articoli-di-valle'], fetch_text: false).map(&:text)
      expect(intros.first).to eq('Doppio intervento dei pompieri volontari.')
    end

    it 'limits the articles of each section' do
      expect(crawler.latest(sections: ['articoli-di-valle'], limit: 2).size).to eq(2)
    end
  end

  describe 'with the live site as source' do
    subject(:crawler) do
      described_class.new(http: Vallelaghi::Scraper::HttpClient.new(delay: 0, retries: 0), source: :live)
    end

    before do
      stub_request(:get, listing_url).to_return(body: fixture('listing_articoli_di_valle.html'))
      stub_request(:get, %r{\Ahttp://www\.valledeilaghi\.it/jcms/2020}).to_return(body: fixture('article_2020.html'))
    end

    let(:articles) { crawler.latest(sections: ['articoli-di-valle'], limit: 1) }

    it 'reads the pages from the site, without archive links' do
      expect(articles.first).to have_attributes(text: a_string_including('SARCHE'), archive_url: nil)
    end

    it 'keeps the original image urls' do
      expect(articles.first.html).to include('src="http://www.valledeilaghi.it/jcms/images/')
    end

    it 'cannot list the archive' do
      expect { crawler.archive }.to raise_error(Vallelaghi::Scraper::Error, /Wayback/)
    end

    it 'rejects unknown sources' do
      expect { described_class.new(source: :ftp) }.to raise_error(ArgumentError, /ftp/)
    end
  end

  describe '#archive' do
    before do
      stub_request(:get, %r{/cdx/search/cdx}).with(query: hash_including('matchType' => 'prefix'))
                                             .to_return(body: fixture('cdx_prefix.json'))
      stub_request(:get, wayback.raw_url(article_url, article_ts)).to_return(body: fixture('article_2020.html'))
    end

    it 'downloads every archived article, skipping the unavailable ones' do
      yielded = []
      articles = crawler.archive { |a| yielded << a }
      expect([articles.map(&:title), yielded]).to eq([['Incidente stradale e caduta massi - Sarche / Vigolo Baselga'],
                                                      articles])
    end

    it 'applies the filters' do
      expect(crawler.archive(sections: ['regionali'])).to be_empty
    end
  end
end

RSpec.describe Vallelaghi::Scraper::Exporters do
  let(:articles) do
    [
      Vallelaghi::Scraper::Article.new(title: 'Vecchio', link: 'http://www.valledeilaghi.it/jcms/1',
                                       section: 'regionali', published_at: Time.iso8601('2016-01-08T16:11:59+01:00'),
                                       text: 'a' * 400),
      Vallelaghi::Scraper::Article.new(title: 'Nuovo & bello', link: 'http://www.valledeilaghi.it/jcms/2',
                                       archive_url: 'https://web.archive.org/web/2020/x', section: 'articoli-di-valle',
                                       author: 'redazione', description: 'Intro', html: '<p>Testo</p>',
                                       published_at: Time.iso8601('2020-09-26T11:11:12+02:00'))
    ]
  end

  around { |example| Dir.mktmpdir { |dir| @dir = dir; example.run } } # rubocop:disable Style/Semicolon

  it 'round-trips through JSON' do
    path = described_class::Json.write(articles, File.join(@dir, 'a.json'))
    expect(described_class::Json.read(path).map(&:to_h)).to eq(articles.map(&:to_h))
  end

  it 'writes a CSV without the HTML' do
    rows = CSV.read(described_class::Csv.write(articles, File.join(@dir, 'a.csv')), headers: true)
    expect([rows.size, rows.headers.include?('html'), rows.first['title']]).to eq([2, false, 'Vecchio'])
  end

  describe 'RSS feeds' do
    let(:paths) { described_class::Rss.write(articles, @dir) }
    let(:feed) { RSS::Parser.parse(File.read(File.join(@dir, 'all.xml'))) }

    it 'writes a feed for everything and one per section' do
      expect(paths.map { |p| File.basename(p) }).to contain_exactly('all.xml', 'regionali.xml', 'articoli-di-valle.xml')
    end

    it 'produces valid RSS 2.0, newest first' do
      paths
      expect(feed.items.map(&:title)).to eq(['Nuovo & bello', 'Vecchio'])
    end

    it 'links to the archived copy and includes the full content' do
      paths
      expect(feed.items.first).to have_attributes(link: 'https://web.archive.org/web/2020/x',
                                                  content_encoded: '<p>Testo</p>', dc_creator: 'redazione')
    end

    it 'falls back to a truncated text when there is no description' do
      paths
      expect(feed.items.last.description).to eq("#{'a' * 300}...")
    end

    it 'limits the number of items' do
      expect(described_class::Rss.build(articles, max_items: 1).items.size).to eq(1)
    end
  end
end

RSpec.describe Vallelaghi::Scraper::CLI do
  let(:out) { StringIO.new }
  let(:err) { StringIO.new }

  def run(*args)
    described_class.start(args, out: out, err: err)
  end

  it 'prints the help' do
    expect([run('--help'), out.string]).to match([0, a_string_including('Usage: vallelaghi-scraper')])
  end

  it 'fails on unknown commands and options' do
    expect([run('nope'), run('--nope')]).to eq([1, 1])
  end

  it 'rejects invalid dates and formats' do
    expect([run('archive', '--from', 'ieri'), run('latest', '-f', 'pdf')]).to eq([1, 1])
  end

  it 'rebuilds the feeds from a JSON export' do
    Dir.mktmpdir do |dir|
      json = Vallelaghi::Scraper::Exporters::Json.write(
        [Vallelaghi::Scraper::Article.new(title: 'T', link: 'http://x/1',
                                          section: 'regionali')], File.join(dir, 'a.json')
      )
      expect(run('feeds', json, '-o', dir)).to eq(0)
      expect(Dir.children(File.join(dir, 'feeds'))).to contain_exactly('all.xml', 'regionali.xml')
    end
  end

  it 'runs a scrape and saves the requested formats' do
    allow(Vallelaghi::Scraper::Crawler).to receive(:new)
      .and_return(instance_double(Vallelaghi::Scraper::Crawler, latest: [Vallelaghi::Scraper::Article.new(title: 'T')]))
    Dir.mktmpdir do |dir|
      expect(run('latest', '-q', '--no-cache', '-f', 'json', '-o', dir)).to eq(0)
      expect(Dir.children(dir)).to eq(['articles.json'])
    end
  end

  it 'uses the Wayback Machine by default and passes the options to the crawler' do
    crawler = instance_double(Vallelaghi::Scraper::Crawler, latest: [])
    allow(Vallelaghi::Scraper::Crawler).to receive(:new).and_return(crawler)
    Dir.mktmpdir { |dir| run('latest', '-q', '--no-cache', '-n', '2', '-o', dir) }
    expect(Vallelaghi::Scraper::Crawler).to have_received(:new).with(hash_including(source: :wayback))
    expect(crawler).to have_received(:latest).with(hash_including(limit: 2))
  end

  it 'prints the articles' do
    article = Vallelaghi::Scraper::Article.new(title: 'Titolo', section: 'regionali', author: 'redazione',
                                               published_at: Time.new(2020, 9, 26), text: "Riga\n\ndue",
                                               link: 'http://x/1')
    allow(Vallelaghi::Scraper::Crawler).to receive(:new)
      .and_return(instance_double(Vallelaghi::Scraper::Crawler, latest: [article]))
    Dir.mktmpdir { |dir| run('latest', '-q', '--no-cache', '--print', '-f', 'json', '-o', dir) }
    expect(out.string).to include("[2020-09-26] Regionali | Titolo (redazione)\n  Riga due\n  http://x/1\n")
  end

  it 'reports that the live site cannot list the archive' do
    expect([run('archive', '--source', 'live', '--no-cache'), err.string]).to match([1, /Wayback/])
  end
end
