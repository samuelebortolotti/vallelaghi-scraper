# frozen_string_literal: true

require_relative 'lib/vallelaghi/scraper/version'

Gem::Specification.new do |spec|
  spec.name          = 'vallelaghi-scraper'
  spec.version       = Vallelaghi::Scraper::VERSION
  spec.authors       = ['Samuele Bortolotti']
  spec.email         = ['samuele.bortolotti@hotmail.it']

  spec.summary       = 'A web scraper for www.valledeilaghi.it, recovered from the Wayback Machine'
  spec.description   = 'Recovers the articles of the defunct valledeilaghi.it online newspaper from the ' \
                       'Internet Archive and exports them as JSON, CSV and RSS feeds.'
  spec.homepage      = 'https://github.com/samuelebortolotti/vallelaghi-scraper'
  spec.license       = 'MIT'
  spec.required_ruby_version = Gem::Requirement.new('>= 3.2.0')

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/master/CHANGELOG.md"
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files         = Dir['lib/**/*.rb', 'exe/*', 'README.md', 'CHANGELOG.md', 'LICENSE.txt']
  spec.bindir        = 'exe'
  spec.executables   = ['vallelaghi-scraper']
  spec.require_paths = ['lib']

  spec.add_dependency 'csv', '~> 3.2'
  spec.add_dependency 'faraday', '~> 2.7'
  spec.add_dependency 'faraday-follow_redirects', '~> 0.3'
  spec.add_dependency 'faraday-retry', '~> 2.2'
  spec.add_dependency 'nokogiri', '~> 1.15'
  spec.add_dependency 'rss', '~> 0.3'
end
