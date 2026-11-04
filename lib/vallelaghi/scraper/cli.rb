# frozen_string_literal: true

require 'date'
require 'logger'
require 'optparse'

module Vallelaghi
  module Scraper
    ##
    # Command line interface (see +exe/vallelaghi-scraper --help+)
    class CLI
      COMMANDS = {
        'latest' => 'newest archived articles of each section (what the original scraper did)',
        'archive' => 'every article ever archived by the Wayback Machine',
        'feeds' => 'rebuild the RSS feeds from a JSON export: feeds FILE.json'
      }.freeze
      FORMATS = %w[json csv rss].freeze

      def self.start(argv = ARGV, out: $stdout, err: $stderr)
        new(out: out, err: err).run(argv)
      end

      def initialize(out: $stdout, err: $stderr)
        @out = out
        @err = err
        @options = {
          output: 'output',
          formats: FORMATS.dup,
          sections: nil,
          delay: 1.0,
          cache: default_cache_dir,
          fetch_text: true,
          verbose: false,
          quiet: false
        }
      end

      # @returns the process exit status
      def run(argv)
        parser = option_parser
        catch(:exit) do
          args = parser.parse(argv)
          command = args.shift

          case command
          when 'latest', 'archive' then scrape(command)
          when 'feeds' then feeds(args.shift)
          when nil then usage_error(parser, 'missing command')
          else usage_error(parser, "unknown command '#{command}'")
          end
        end
      rescue OptionParser::ParseError, ArgumentError => e
        usage_error(parser, e.message)
      end

      private

      def scrape(command)
        http = HttpClient.new(delay: @options[:delay], cache_dir: @options[:cache], logger: logger)
        crawler = Crawler.new(http: http, logger: logger)
        articles = []
        begin
          if command == 'latest'
            articles = crawler.latest(sections: @options[:sections] || VallelaghiConstants::SECTIONS.keys,
                                      fetch_text: @options[:fetch_text])
          else
            crawler.archive(sections: @options[:sections], from: @options[:from], to: @options[:to],
                            limit: @options[:limit]) { |article| articles << article }
          end
        rescue Interrupt
          logger.warn("Interrupted: saving the #{articles.size} articles retrieved so far")
        end
        export(articles)
        0
      end

      def feeds(path)
        raise ArgumentError, 'feeds needs the path of a JSON export' unless path
        raise ArgumentError, "#{path} does not exist" unless File.file?(path)

        written = Exporters::Rss.write(Exporters::Json.read(path), File.join(@options[:output], 'feeds'),
                                       max_items: @options[:max_items])
        written.each { |p| @out.puts(p) }
        0
      end

      def export(articles)
        dir = @options[:output]
        written = []
        written << Exporters::Json.write(articles, File.join(dir, 'articles.json')) if format?('json')
        written << Exporters::Csv.write(articles, File.join(dir, 'articles.csv')) if format?('csv')
        if format?('rss')
          written.concat(Exporters::Rss.write(articles, File.join(dir, 'feeds'), max_items: @options[:max_items]))
        end
        logger.info("#{articles.size} articles saved")
        written.each { |p| @out.puts(p) }
      end

      def format?(name)
        @options[:formats].include?(name)
      end

      def logger
        @logger ||= Logger.new(@err).tap do |l|
          l.level = if @options[:quiet] then Logger::WARN
                    elsif @options[:verbose] then Logger::DEBUG
                    else Logger::INFO
                    end
          l.formatter = proc { |severity, _time, _prog, msg| "#{"#{severity}: " unless severity == 'INFO'}#{msg}\n" }
        end
      end

      def default_cache_dir
        File.join(ENV.fetch('XDG_CACHE_HOME', File.join(Dir.home, '.cache')), 'vallelaghi-scraper')
      end

      def parse_date(value, last: false)
        case value
        when /\A\d{4}\z/ then last ? Date.new(value.to_i, 12, 31) : Date.new(value.to_i, 1, 1)
        when /\A\d{4}-?\d{2}\z/
          first = Date.strptime(value.delete('-'), '%Y%m')
          last ? first.next_month.prev_day : first
        else Date.parse(value)
        end
      rescue Date::Error
        raise ArgumentError, "invalid date '#{value}'"
      end

      def option_parser
        OptionParser.new do |o|
          o.banner = 'Usage: vallelaghi-scraper COMMAND [options]'
          o.separator ''
          o.separator 'Recovers the articles of the (defunct) valledeilaghi.it newspaper from the Wayback Machine.'
          o.separator ''
          o.separator 'Commands:'
          COMMANDS.each { |name, desc| o.separator format('    %-10<name>s %<desc>s', name: name, desc: desc) }
          o.separator ''
          o.separator 'Options:'
          o.on('-o', '--output DIR', "Output directory (default: #{@options[:output]})") { |v| @options[:output] = v }
          o.on('-f', '--formats LIST', Array,
               "Comma separated formats among #{FORMATS.join(', ')} (default: all)") do |v|
            unknown = v - FORMATS
            raise ArgumentError, "unknown format(s): #{unknown.join(', ')}" unless unknown.empty?

            @options[:formats] = v
          end
          o.on('-s', '--sections LIST', Array,
               "Comma separated sections: #{(VallelaghiConstants::SECTIONS.keys +
                                             VallelaghiConstants::EXTRA_SECTIONS.keys).join(', ')}") do |v|
            @options[:sections] = v
          end
          o.on('--from DATE', 'archive: oldest publication date (YYYY, YYYY-MM or YYYY-MM-DD)') do |v|
            @options[:from] = parse_date(v)
          end
          o.on('--to DATE', 'archive: newest publication date (YYYY, YYYY-MM or YYYY-MM-DD)') do |v|
            @options[:to] = parse_date(v, last: true)
          end
          o.on('-n', '--limit N', Integer, 'archive: maximum number of articles (newest first)') do |v|
            @options[:limit] = v
          end
          o.on('--no-text', 'latest: do not download the article pages (listing data only)') do
            @options[:fetch_text] = false
          end
          o.on('--max-items N', Integer, 'Maximum number of items in each RSS feed (default: all)') do |v|
            @options[:max_items] = v
          end
          o.on('--delay SECONDS', Float, "Pause between requests (default: #{@options[:delay]})") do |v|
            @options[:delay] = v
          end
          o.on('--cache DIR', "HTTP cache directory (default: #{@options[:cache]})") { |v| @options[:cache] = v }
          o.on('--no-cache', 'Disable the HTTP cache') { @options[:cache] = nil }
          o.on('-v', '--verbose', 'Log every request') { @options[:verbose] = true }
          o.on('-q', '--quiet', 'Only log warnings and errors') { @options[:quiet] = true }
          o.on('-V', '--version', 'Print the version') do
            @out.puts(VERSION)
            throw :exit, 0
          end
          o.on('-h', '--help', 'Print this help') do
            @out.puts(o)
            throw :exit, 0
          end
        end
      end

      def usage_error(parser, message)
        @err.puts("Error: #{message}")
        @err.puts(parser)
        1
      end
    end
  end
end
