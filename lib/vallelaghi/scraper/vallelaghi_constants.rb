# frozen_string_literal: true

module Vallelaghi
  module Scraper
    ##
    # Constants related to the @see {Valle dei laghi}[http://www.valledeilaghi.it] site.
    #
    # The site is no longer online: every URL here is the *original* one, which is
    # looked up in the Wayback Machine (see Vallelaghi::Scraper::Wayback).
    module VallelaghiConstants
      # Valle dei laghi base url
      BASE_URL = 'http://www.valledeilaghi.it'
      # Root of the Joomla installation that hosted the newspaper
      SITE_URL = "#{BASE_URL}/jcms".freeze
      # Prefix used to enumerate every archived page of the newspaper
      ARCHIVE_PREFIX = 'valledeilaghi.it/jcms/'

      # Newspaper sections: slug => human readable name
      SECTIONS = {
        'articoli-di-valle' => 'Articoli di Valle',
        'regionali' => 'Regionali',
        'nazionali-ed-estero' => 'Nazionali ed estero',
        'editoriali' => 'Editoriali',
        'lettere-al-giornale' => 'Lettere al giornale'
      }.freeze

      # Sections that only appear in old article URLs (they had no listing page)
      EXTRA_SECTIONS = {
        'vvf' => 'Vigili del fuoco',
        'uncategorised' => 'Senza categoria'
      }.freeze

      # URL for the 'Articoli di Valle' section
      ARTICOLI_DI_VALLE = "#{SITE_URL}/articoli/articoli-di-valle".freeze
      # URL for the 'Articoli Regionali' section
      ARTICOLI_REGIONALI = "#{SITE_URL}/articoli/regionali".freeze
      # URL for the 'Articoli nazionali ed estero' section
      ARTICOLI_NAZIONALI = "#{SITE_URL}/articoli/nazionali-ed-estero".freeze
      # URL for the 'Articoli editoriali' section
      ARTICOLI_EDITORIALI = "#{SITE_URL}/articoli/editoriali".freeze
      # URL for the 'Lettere al giornale' section
      LETTERE_AL_GIORNALE = "#{SITE_URL}/articoli/lettere-al-giornale".freeze

      # Listing page of a section
      #
      # @param +slug+:: section slug, one of the keys of SECTIONS
      def self.section_url(slug)
        "#{SITE_URL}/articoli/#{slug}"
      end

      # Human readable name of a section (falls back to the slug itself)
      def self.section_name(slug)
        SECTIONS[slug] || EXTRA_SECTIONS[slug] || slug.to_s
      end
    end
  end
end
