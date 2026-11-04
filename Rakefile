# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rdoc/task'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

desc 'Run rubocop'
RuboCop::RakeTask.new

desc 'Generate documentation'
RDoc::Task.new do |rdoc|
  rdoc.main = 'README.md'
  rdoc.rdoc_dir = 'doc'
  rdoc.title = 'Vallelaghi-Scraper Documentation'
  rdoc.rdoc_files.include('README.md', 'CHANGELOG.md', 'lib/**/*.rb')
end

desc 'Run specs'
RSpec::Core::RakeTask.new(:spec)

task default: %i[spec rubocop]
