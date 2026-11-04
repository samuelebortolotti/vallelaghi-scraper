# frozen_string_literal: true

RSpec.describe Vallelaghi::Scraper::Article do
  subject(:article) do
    described_class.new(title: 'Titolo', link: 'http://www.valledeilaghi.it/jcms/20200926/a/b',
                        description: 'Intro', published_at: Time.iso8601('2020-09-26T11:11:12+02:00'))
  end

  context 'when the article object is instantiated' do
    it 'has a title, a link and a description' do
      expect([article.title, article.link, article.description]).to all(be_a(String))
    end

    it 'does not have a text' do
      expect(article.text).to be_nil
    end

    it 'rejects unknown attributes' do
      expect { described_class.new(foo: 1) }.to raise_error(ArgumentError, /foo/)
    end
  end

  describe '#to_h' do
    it 'serializes the publication date as ISO 8601' do
      expect(article.to_h).to include(title: 'Titolo', published_at: '2020-09-26T11:11:12+02:00')
    end

    it 'contains every attribute' do
      expect(article.to_h.keys).to eq(described_class::ATTRIBUTES)
    end
  end

  describe '.from_h' do
    it 'round-trips through #to_h, also with string keys' do
      copy = described_class.from_h(article.to_h.transform_keys(&:to_s))
      expect(copy.to_h).to eq(article.to_h)
    end
  end

  describe '#merge!' do
    it 'overwrites with non-blank values only' do
      article.merge!(title: 'Nuovo', description: '', text: nil, author: 'redazione')
      expect(article).to have_attributes(title: 'Nuovo', description: 'Intro', text: nil, author: 'redazione')
    end
  end
end
