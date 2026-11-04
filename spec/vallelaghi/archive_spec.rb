# frozen_string_literal: true

RSpec.describe Vallelaghi::Scraper::ArchiveIndex do
  subject(:index) { described_class.new(captures) }

  let(:captures) do
    JSON.parse(fixture('cdx_prefix.json')).drop(1).map { |ts, url| Vallelaghi::Scraper::Wayback::Capture.new(ts, url) }
  end

  describe '.parse' do
    it 'understands every url scheme used by the site' do
      expect(%w[
        http://www.valledeilaghi.it/jcms/201601086906/regionali/festival-del-benessere-mezzocorona.htm
        http://www.valledeilaghi.it/jcms/index.php/20160108/regionali/festival-del-benessere-mezzocorona.html
      ].map { |u| described_class.parse(u)[:key] }.uniq).to eq(['20160108/festival-del-benessere-mezzocorona'])
    end

    it 'ignores pages that are not articles' do
      expect(described_class.parse('http://www.valledeilaghi.it:80/jcms/articoli/articoli-di-valle')).to be_nil
    end

    it 'ignores invalid dates' do
      expect(described_class.parse('http://www.valledeilaghi.it/jcms/20200231/regionali/x')).to be_nil
    end
  end

  it 'merges the different urls of the same article' do
    expect(index.entries.map(&:key)).to eq(%w[
                                             20200926/incidente-stradale-e-caduta-massi-sarche-vigolo-baselga
                                             20160807/traffico-bloccato-per-incidente-bus-de-vela
                                             20160108/festival-del-benessere-mezzocorona
                                           ])
  end

  it 'keeps the most recent capture and recovers the missing section' do
    entry = index.entries.find { |e| e.slug == 'traffico-bloccato-per-incidente-bus-de-vela' }
    expect([entry.section, entry.capture.timestamp]).to eq(%w[uncategorised 20190721031113])
  end

  it 'normalizes the link' do
    expect(index.entries.last.link)
      .to eq('http://www.valledeilaghi.it/jcms/index.php/20160108/regionali/festival-del-benessere-mezzocorona.html')
  end

  it 'filters by section, date and limit' do
    expect(index.entries(sections: %w[regionali uncategorised], from: Date.new(2016, 1, 1),
                         to: Date.new(2016, 12, 31), limit: 1).map(&:slug))
      .to eq(['traffico-bloccato-per-incidente-bus-de-vela'])
  end
end

RSpec.describe Vallelaghi::Scraper::Wayback do
  subject(:wayback) { described_class.new(Vallelaghi::Scraper::HttpClient.new(delay: 0)) }

  let(:url) { 'http://www.valledeilaghi.it/jcms/articoli/articoli-di-valle' }

  it 'builds raw, view and image urls' do
    expect([described_class.raw_url(url, '2020'), described_class.view_url(url, '2020'),
            described_class.image_url(url, '2020')])
      .to eq(["https://web.archive.org/web/2020id_/#{url}", "https://web.archive.org/web/2020/#{url}",
              "https://web.archive.org/web/2020im_/#{url}"])
  end

  it 'parses Wayback urls' do
    expect(described_class.parse_url("https://web.archive.org/web/20200926142122id_/#{url}").to_a)
      .to eq(['20200926142122', url])
  end

  it 'lists the captures of a url and finds the latest' do
    stub_request(:get, %r{/cdx/search/cdx}).with(query: hash_including('url' => url))
                                           .to_return(body: '[["timestamp","original"],["2019","a"],["2020","b"]]')
    expect(wayback.latest_capture(url).to_a).to eq(%w[2020 b])
  end

  it 'handles urls that were never archived' do
    stub_request(:get, %r{/cdx/search/cdx}).to_return(body: '')
    expect(wayback.latest_capture(url)).to be_nil
  end

  it 'follows the redirect to the closest capture' do
    stub_request(:get, described_class.raw_url(url, '2020'))
      .to_return(status: 302, headers: { 'Location' => described_class.raw_url(url, '20200926142122') })
    stub_request(:get, described_class.raw_url(url, '20200926142122')).to_return(body: 'ok')
    page = wayback.fetch(url, timestamp: '2020')
    expect([page.body, page.capture.timestamp]).to eq(%w[ok 20200926142122])
  end
end
