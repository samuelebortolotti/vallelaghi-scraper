# frozen_string_literal: true

require 'rubocop/rake_task'
require 'rdoc/task'

desc 'Run rubocop'
RuboCop::RakeTask.new do |task|
  task.requires << 'rubocop-rspec'
  task.fail_on_error = false
end

desc 'Generate documentation'
RDoc::Task.new do |rdoc|
  rdoc.main = 'README.md'
  rdoc.rdoc_dir = 'doc'
  rdoc.title = 'Vallelaghi-Scraper Documentation'
  rdoc.rdoc_files.include('README.md', 'lib/scraper/*.rb')
end
