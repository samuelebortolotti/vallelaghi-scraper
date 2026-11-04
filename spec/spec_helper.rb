# frozen_string_literal: true

require 'tmpdir'
require 'webmock/rspec'
require 'vallelaghi/scraper'

# The site is gone and the Wayback Machine is slow: the specs never touch the network
WebMock.disable_net_connect!

# Helpers to read the HTML pages archived by the Wayback Machine that are used as fixtures
module FixtureHelpers
  def fixture_path(name)
    File.expand_path("fixtures/#{name}", __dir__)
  end

  def fixture(name)
    File.read(fixture_path(name))
  end
end

RSpec.configure do |config|
  config.include FixtureHelpers
  config.disable_monkey_patching!
  config.order = :random
  config.expect_with(:rspec) { |c| c.syntax = :expect }
end
