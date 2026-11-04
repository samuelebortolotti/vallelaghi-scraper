# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'json'
require 'logger'
require 'faraday'
require 'faraday/retry'
require 'faraday/follow_redirects'

module Vallelaghi
  module Scraper
    ##
    # Polite HTTP client: throttles requests, retries transient failures (the
    # Wayback Machine answers 429/503 quite often) and keeps an optional on-disk
    # cache so that long crawls can be interrupted and resumed.
    class HttpClient
      # Raised when a page cannot be retrieved
      class Error < Vallelaghi::Scraper::Error
        attr_reader :status

        def initialize(message, status: nil)
          super(message)
          @status = status
        end
      end

      # Body of a response together with the final URL (after redirects)
      Response = Struct.new(:body, :url, keyword_init: true)

      USER_AGENT = "vallelaghi-scraper/#{VERSION} (+https://github.com/samuelebortolotti/vallelaghi-scraper)".freeze
      RETRY_STATUSES = [429, 500, 502, 503, 504].freeze

      attr_reader :delay, :cache_dir

      # @param +delay+:: minimum number of seconds between two network requests
      # @param +cache_dir+:: directory where responses are cached, +nil+ to disable the cache
      # @param +retries+:: how many times a failed request is retried
      # @param +timeout+:: timeout of a single request, in seconds
      # @param +logger+:: a +Logger+
      def initialize(delay: 1.0, cache_dir: nil, retries: 5, timeout: 60, logger: Logger.new(nil))
        @delay = delay.to_f
        @cache_dir = cache_dir
        @logger = logger
        @last_request_at = nil
        @connection = build_connection(retries, timeout)
      end

      # Performs a GET request
      #
      # @param +url+:: absolute url
      # @returns a Response
      # @raises HttpClient::Error when the page cannot be retrieved
      def get(url)
        cached = read_cache(url)
        return cached if cached

        throttle
        @logger.debug("GET #{url}")
        response = @connection.get(url)
        unless response.success?
          raise Error.new("GET #{url} failed with status #{response.status}", status: response.status)
        end

        result = Response.new(body: response.body.to_s, url: response.env.url.to_s)
        write_cache(url, result)
        result
      rescue Faraday::Error => e
        raise Error.new("GET #{url} failed: #{e.message}", status: e.response_status)
      end

      private

      def build_connection(retries, timeout)
        Faraday.new(headers: { 'User-Agent' => USER_AGENT },
                    request: { timeout: timeout, open_timeout: timeout }) do |f|
          f.request :retry,
                    max: retries,
                    interval: 2,
                    backoff_factor: 2,
                    max_interval: 120,
                    interval_randomness: 0.5,
                    retry_statuses: RETRY_STATUSES,
                    methods: %i[get],
                    exceptions: Faraday::Retry::Middleware::DEFAULT_EXCEPTIONS + [Faraday::ConnectionFailed],
                    retry_block: lambda { |env:, retry_count:, will_retry_in:, **|
                      @logger.warn("Retrying #{env.url} (#{retry_count + 1}/#{retries}) in #{will_retry_in.round(1)}s")
                    }
          f.response :follow_redirects, limit: 5
          f.adapter Faraday.default_adapter
        end
      end

      def throttle
        if @last_request_at
          wait = @delay - (monotonic_now - @last_request_at)
          sleep(wait) if wait.positive?
        end
        @last_request_at = monotonic_now
      end

      def monotonic_now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def cache_path(url)
        digest = Digest::SHA256.hexdigest(url)
        File.join(@cache_dir, digest[0, 2], "#{digest}.json")
      end

      def read_cache(url)
        return nil unless @cache_dir

        path = cache_path(url)
        return nil unless File.file?(path)

        data = JSON.parse(File.read(path))
        Response.new(body: data.fetch('body'), url: data.fetch('url'))
      rescue JSON::ParserError, KeyError
        nil
      end

      def write_cache(url, response)
        return unless @cache_dir

        path = cache_path(url)
        FileUtils.mkdir_p(File.dirname(path))
        body = response.body.dup.force_encoding(Encoding::UTF_8).scrub
        File.write(path, JSON.generate({ 'url' => response.url, 'body' => body }))
      end
    end
  end
end
