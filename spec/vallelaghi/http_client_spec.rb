# frozen_string_literal: true

RSpec.describe Vallelaghi::Scraper::HttpClient do
  let(:url) { 'https://web.archive.org/web/2020id_/http://www.valledeilaghi.it/' }

  # no real waiting between retries
  before { allow_any_instance_of(Faraday::Retry::Middleware).to receive(:sleep) } # rubocop:disable RSpec/AnyInstance

  it 'retries when the Wayback Machine is overloaded' do
    stub_request(:get, url).to_return({ status: 503 }, { status: 429 }, { status: 200, body: 'ok' })
    expect(described_class.new(delay: 0).get(url).body).to eq('ok')
  end

  it 'raises an error with the status when the page does not exist' do
    stub_request(:get, url).to_return(status: 404)
    expect { described_class.new(delay: 0).get(url) }
      .to raise_error(described_class::Error) { |e| expect(e.status).to eq(404) }
  end

  it 'gives up after the configured retries' do
    stub_request(:get, url).to_return(status: 503)
    expect { described_class.new(delay: 0, retries: 2).get(url) }.to raise_error(described_class::Error, /503/)
  end

  it 'caches the responses on disk' do
    Dir.mktmpdir do |dir|
      stub = stub_request(:get, url).to_return(body: 'perché')
      bodies = Array.new(2) { described_class.new(delay: 0, cache_dir: dir).get(url).body }
      expect(bodies).to eq(%w[perché perché])
      expect(stub).to have_been_requested.once
    end
  end

  it 'sends its own user agent' do
    stub_request(:get, url).to_return(body: 'ok')
    described_class.new(delay: 0).get(url)
    expect(a_request(:get, url).with(headers: { 'User-Agent' => /\Avallelaghi-scraper/ })).to have_been_made
  end
end
