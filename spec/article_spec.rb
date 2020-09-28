# frozen_string_literal: true

require_relative '../lib/scraper/article'
require 'faker'

RSpec.describe Article do
  subject(:article) { described_class.new(Faker::Lorem.characters(:number => 5), Faker::Internet.url, Faker::Lorem.characters(:number => 20)) }

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
  end
end
