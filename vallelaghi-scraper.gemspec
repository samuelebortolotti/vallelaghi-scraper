require_relative 'lib/vallelaghi/scraper/version'

Gem::Specification.new do |spec|
  spec.name          = 'vallelaghi-scraper'
  spec.version       = Vallelaghi::Scraper::VERSION
  spec.authors       = ['Samuele Bortolotti']
  spec.email         = ['samuele.bortolotti@hotmail.it']

  spec.summary       = 'A web scaper for www.valledeilaghi.it'
  spec.homepage      = 'https://github.com/samuelebortolotti/vallelaghi-scraper'
  spec.license       = 'MIT'
  spec.required_ruby_version = Gem::Requirement.new('>= 2.3.0')

  spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git. (I have to change it)
  spec.files         = Dir['lib/vallelaghi/*.rb'] + Dir['lib/vallelaghi/scraper/*.rb'] + Dir['lib/vallelaghi/scraper/article/*.rb']
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']
  
  # dependencies
  spec.add_dependency 'kimurai', '~> 1.4.0'

  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'rubocop', '~> 0.92.0'
  spec.add_development_dependency 'rspec', '~> 3.9'
  spec.add_development_dependency 'rubocop-rspec', '~> 1.43.2'
  spec.add_development_dependency 'faker', '~> 2.14'
  spec.add_development_dependency 'httparty', '~> 0.18.1'
  spec.add_development_dependency 'rdoc', '~> 6.2.1'
end
