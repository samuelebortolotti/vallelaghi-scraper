# Vallelaghi-Scraper

A web scraper for www.valledeilaghi.it, the online newspaper of the Valle dei Laghi (Trentino).

I made this small project just to pass the time and to have the most recent news of my valley at hand.
The site has since suspended publication and is now offline, so the scraper recovers the articles from the
[Wayback Machine](https://web.archive.org/) of the Internet Archive instead.

It can:

- get the **latest** articles of each section, as the site looked in its last archived snapshot (this is what the
  original scraper did when the site was online);
- recover the **whole archive**: every article captured by the Wayback Machine (about 5,000, from 2007 to 2020),
  filtered by section and date if needed;
- export the articles as **JSON**, **CSV** and **RSS 2.0 feeds** (one for every section plus one with everything).
  Feed items include the full text and link to the archived copy of each article, with images served by the archive.

## Installation

You need Ruby >= 3.2 (the version used for development is in `.ruby-version`).

```bash
git clone https://github.com/samuelebortolotti/vallelaghi-scraper.git
cd vallelaghi-scraper
bin/setup                  # bundle install
bundle exec rake install   # optional: install the gem and the `vallelaghi-scraper` command
```

## Usage

```bash
bundle exec exe/vallelaghi-scraper COMMAND [options]
```

| Command   | What it does                                                         |
|-----------|----------------------------------------------------------------------|
| `latest`  | newest archived listing page of each section, with the full articles |
| `archive` | every article ever archived by the Wayback Machine                   |
| `feeds`   | rebuild the RSS feeds from a JSON export: `feeds output/articles.json` |

Examples:

```bash
# latest articles of every section
bundle exec exe/vallelaghi-scraper latest

# the whole archive (slow: the Wayback Machine is rate limited, expect a few hours)
bundle exec exe/vallelaghi-scraper archive

# 2016 articles of two sections, JSON and RSS only
bundle exec exe/vallelaghi-scraper archive --from 2016 --to 2016 -s articoli-di-valle,regionali -f json,rss

# the 50 most recent articles, into another folder
bundle exec exe/vallelaghi-scraper archive -n 50 -o news

# feeds with at most 20 items, built from a previous export
bundle exec exe/vallelaghi-scraper feeds output/articles.json --max-items 20
```

Everything is written to `output/` (change it with `-o`):

```
output/
├── articles.json
├── articles.csv
└── feeds/
    ├── all.xml
    ├── articoli-di-valle.xml
    ├── regionali.xml
    └── ...
```

Run `bundle exec exe/vallelaghi-scraper --help` to see every option.

### Notes

- Requests are throttled (`--delay`, 1 second by default) and retried with exponential backoff when the Wayback
  Machine answers `429`/`5xx`.
- Every response is cached in `~/.cache/vallelaghi-scraper` (`--cache DIR`, `--no-cache`): an interrupted crawl
  resumes where it stopped, and pressing `Ctrl-C` still saves the articles retrieved so far.
- A few articles were never archived: in `latest` mode they keep the data shown on the listing page (title,
  intro, date) but have no text and no `archive_url`; in `archive` mode they are skipped.

## Using it as a library

```ruby
require 'vallelaghi/scraper'

crawler = Vallelaghi::Scraper::Crawler.new(
  http: Vallelaghi::Scraper::HttpClient.new(cache_dir: '/tmp/vdl-cache')
)
articles = crawler.archive(sections: ['regionali'], from: Date.new(2020, 1, 1), limit: 10)
Vallelaghi::Scraper::Exporters::Rss.write(articles, 'feeds')
```

## Development

After checking out the repo, run `bin/setup` to install the dependencies, then:

- `bundle exec rake` runs the specs and RuboCop;
- `bundle exec rake spec` runs only the specs (they use archived pages saved in `spec/fixtures` and never touch
  the network);
- `bundle exec rake rdoc` generates the documentation in `doc/`;
- `bin/console` opens an interactive prompt with the gem loaded.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
