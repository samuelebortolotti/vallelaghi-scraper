# Vallelaghi-Scraper

A web scraper for www.valledeilaghi.it, the online newspaper of the Valle dei Laghi (Trentino).

I made this small project just to pass the time and to have the most recent news of my valley at hand.
The site has since suspended publication and is now offline, so by default the scraper reads everything from the
[Wayback Machine](https://web.archive.org/) of the Internet Archive.

It can:

- get the **latest** articles of each section, as the site looked in its last archived snapshot (this is what the
  original scraper did when the site was online);
- recover the **whole archive**: every article captured by the Wayback Machine (about 5,000, from 2007 to 2020),
  filtered by section and date if needed;
- export the articles as **JSON**, **CSV** and **RSS 2.0 feeds** (one for every section plus one with everything).
  Feed items include the full text and link to the archived copy of each article, with images served by the archive.

## Installation

You need Ruby >= 3.2 (the version used for development is in `.ruby-version`; with rbenv just run
`rbenv install` in the project folder).

```bash
git clone https://github.com/samuelebortolotti/vallelaghi-scraper.git
cd vallelaghi-scraper
bin/setup                  # bundle install
bundle exec rake install   # optional: install the gem and the `vallelaghi-scraper` command
```

## Try it

The quickest way to see what the scraper produces is the demo task, which downloads the 3 latest articles of each
section from the Wayback Machine (about a minute and a half the first time, instant afterwards thanks to the cache)
and prints them:

```bash
bundle exec rake demo
```

```
[2020-09-26] Articoli di Valle | Incidente stradale e caduta massi - Sarche / Vigolo Baselga (redazione)
  Doppio intervento dei pompieri volontari. SARCHE / VIGOLO BASELGA – Questa mattina verso le 10.30, sabato 26...
  https://web.archive.org/web/20201026185205/http://www.valledeilaghi.it/jcms/20200926/articoli-di-valle/...

[2020-09-25] Nazionali ed estero | Esercitazione Vardirex 2020 - Scanno (Comando Truppe Alpine)
  ...
```

The files are saved in `output/demo/`. To look at them:

```bash
# JSON: every field of an article (title, link, archive_url, section, author, published_at,
# description, image_url, text, html)
jq '.articles[0]' output/demo/articles.json
jq -r '.articles[] | "\(.published_at[:10])  \(.title)"' output/demo/articles.json

# CSV: open it with LibreOffice Calc (or any spreadsheet), or from the terminal
ruby -rcsv -e 'CSV.foreach(ARGV[0], headers: true) { |r| puts r.values_at("section", "title").join(" | ") }' \
  output/demo/articles.csv

# RSS: serve the folder and subscribe to http://localhost:8000/feeds/all.xml with any feed reader
# (Thunderbird, NetNewsWire, Feeder, ...), or just open the .xml file in a browser
python3 -m http.server 8000 -d output/demo
```

Then try a slice of the archive, for example the articles of January 2016:

```bash
bundle exec exe/vallelaghi-scraper archive --from 2016-01 --to 2016-01 --print -o output/2016-01
```

## Usage

```bash
bundle exec exe/vallelaghi-scraper COMMAND [options]
```

| Command   | What it does                                                           |
|-----------|------------------------------------------------------------------------|
| `latest`  | newest listing page of each section, with the full articles            |
| `archive` | every article ever archived by the Wayback Machine                     |
| `feeds`   | rebuild the RSS feeds from a JSON export: `feeds output/articles.json` |

Main options:

| Option                        | Meaning                                                                 |
|-------------------------------|-------------------------------------------------------------------------|
| `-s`, `--sections LIST`       | only these sections, e.g. `articoli-di-valle,regionali`                 |
| `--from DATE`, `--to DATE`    | `archive` only: publication dates, as `YYYY`, `YYYY-MM` or `YYYY-MM-DD` |
| `-n`, `--limit N`             | `archive`: at most N articles (newest first); `latest`: N per section   |
| `-p`, `--print`               | also print the articles in the terminal                                 |
| `-f`, `--formats LIST`        | output formats among `json`, `csv`, `rss` (default: all)                |
| `-o`, `--output DIR`          | output directory (default: `output`)                                    |
| `--max-items N`               | at most N items in each RSS feed                                        |
| `--source wayback\|live`      | where pages are read from (default: `wayback`, see below)               |
| `--no-text`                   | `latest` only: skip the article pages, keep the listing data            |
| `--delay`, `--cache`, `--no-cache`, `-v`, `-q` | throttling, cache and logging (see below)              |

Run `bundle exec exe/vallelaghi-scraper --help` to see every option.

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

### Sources

- `--source wayback` (the default): pages come from the Wayback Machine. `latest` uses the most recent snapshot of
  each section, `archive` lists every capture through the
  [CDX API](https://github.com/internetarchive/wayback/tree/master/wayback-cdx-server). Links and images in the
  output point to the archived copies.
- `--source live`: pages are read from www.valledeilaghi.it itself, like the original scraper did. The site is
  offline at the moment, so this is only useful if it ever comes back; it works with `latest` only.

### Notes

- Requests are throttled (`--delay`, 1 second by default) and retried with exponential backoff when the server
  answers `429`/`5xx`.
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
- `bundle exec rake demo` runs a small real crawl (see [Try it](#try-it));
- `bundle exec rake rdoc` generates the documentation in `doc/`;
- `bin/console` opens an interactive prompt with the gem loaded.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
