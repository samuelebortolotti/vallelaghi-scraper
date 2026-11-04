# Changelog

## 0.2.0

The site is offline, so the project is resumed on top of the Wayback Machine.

- Articles are recovered from the Internet Archive instead of the live site
- New `archive` mode: every archived article (2007-2020), enumerated through the Wayback CDX index, with
  de-duplication of the different URL schemes used by the site and filters by section, date and number
- `latest` mode: the newest archived listing page of each section, as the original scraper did
- RSS 2.0 feeds (one per section plus one with everything), with full content, links and images pointing to the
  archived copies
- Article metadata: author, publication date, section, archive URL and cleaned HTML body
- New `vallelaghi-scraper` command line interface with JSON, CSV and RSS output
- `--source wayback|live`: pages come from the Wayback Machine by default; `live` reads the site itself
- `--print` shows the articles in the terminal, `--limit` also caps the articles per section in `latest` mode
- `rake demo`: a small real crawl to try the scraper
- Articles whose page was never archived (or `--no-text`) use the intro of the listing page as `text`/`html`
  instead of `null`
- Polite HTTP client with throttling, retries with exponential backoff and an on-disk cache to resume long crawls
- Replaced Kimurai (unmaintained, needed Selenium and Firefox) with Faraday and Nokogiri
- Fixed: the text of an article was always taken from its third paragraph only (the fallback to the other
  paragraphs never triggered); now the whole text is collected, without the social sharing widgets
- Fixed: missing dependency on ActiveSupport for `String#squish`
- Fixed: the gem executable was never packaged (`bindir` pointed to an empty `exe/` folder)
- Specs no longer depend on the network: they use archived pages as fixtures (WebMock)
- Requires Ruby >= 3.2; updated every dependency; removed the Travis CI configuration

### 0.1.1

- Unfortunately the project was abandoned because the site suspended publication.

## 0.1.0

- Correctly scrapes the most recent valley, regional, national, editorial articles and letters to the newspaper,
  that are those present on the last page of each section
