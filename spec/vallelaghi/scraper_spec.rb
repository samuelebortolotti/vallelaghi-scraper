# frozen_string_literal: true

RSpec.describe Vallelaghi::Scraper do
  it 'has a version number' do
    expect(Vallelaghi::Scraper::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
  end

  describe Vallelaghi::Scraper::VallelaghiConstants do
    it 'builds the listing url of a section' do
      expect(described_class.section_url('regionali')).to eq(described_class::ARTICOLI_REGIONALI)
    end

    it 'names known and unknown sections' do
      expect(%w[vvf articoli-di-valle other].map { |s| described_class.section_name(s) })
        .to eq(['Vigili del fuoco', 'Articoli di Valle', 'other'])
    end
  end

  describe Vallelaghi::Scraper::Util do
    it 'squishes whitespace, non-breaking spaces included' do
      expect(described_class.squish("  a \n\t b ")).to eq('a b')
    end

    it 'resolves relative links against the site' do
      expect(described_class.absolute_url('/jcms/images/a b.jpg'))
        .to eq('http://www.valledeilaghi.it/jcms/images/a%20b.jpg')
    end

    it 'ignores blank and javascript links' do
      expect([nil, '', '#top', 'javascript:void(0)'].map { |h| described_class.absolute_url(h) }).to all(be_nil)
    end
  end
end
