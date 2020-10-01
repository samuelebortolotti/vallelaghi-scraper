# frozen_string_literal: true

RSpec.describe Vallelaghi::Scraper::Article do
  subject(:article) { described_class.new(Faker::Lorem.characters(number: 5), Faker::Internet.url, Faker::Lorem.characters(number: 20), Faker::Internet.url) }

  context 'when the article object is instantiated' do
    it 'has a title' do
      expect(article.title).not_to be nil
    end

    it 'has a link' do
      expect(article.link).not_to be nil
    end

    it 'has a description' do
      expect(article.description).not_to be nil
    end

    it 'does not have a text' do
      expect(article.text).to be nil
    end

    it 'has a text' do
      article.text = Faker::Lorem.characters(number: 40)
      expect(article.text).not_to be nil
    end
  end

  describe '#to_hash' do
    it 'returns an hash object' do
      expect(article.to_hash.is_a?(Hash)).to be true
    end
  end
end
