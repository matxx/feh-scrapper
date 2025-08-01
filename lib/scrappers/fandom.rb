# frozen_string_literal: true

require 'mediawiki_api'

require 'scrappers/base'
require 'scrappers/fandoms/banner_focuses'
require 'scrappers/fandoms/distributions'
require 'scrappers/fandoms/divine_codes'
require 'scrappers/fandoms/duo_heroes'
require 'scrappers/fandoms/images'
require 'scrappers/fandoms/legendary_heroes'
require 'scrappers/fandoms/mythic_heroes'
require 'scrappers/fandoms/resplendent_heroes'
require 'scrappers/fandoms/sacred_seal_costs'
require 'scrappers/fandoms/skills'
require 'scrappers/fandoms/skills_weapons'
require 'scrappers/fandoms/summon_pool'
require 'scrappers/fandoms/unit_skills'
require 'scrappers/fandoms/unit_stats'
require 'scrappers/fandoms/units'
require 'scrappers/fandoms/units_fodder'
require 'scrappers/fandoms/utils'

module Scrappers
  # for all Fandom objects, the source of the data depends on the type of its key
  # - string : the data comes from Fandom
  # - symbol : the data has been injected by this repo
  # ex :
  # - `unit['Properties']` comes from fandom (and is a string with comma-separated values ; ex: 'aided,aide')
  # - `unit[:properties]` has been added by this repo (and is an array of strings ; ex: ['aided', 'aide'])
  class Fandom < Base
    include Scrappers::Fandoms::BannerFocuses
    include Scrappers::Fandoms::Distributions
    include Scrappers::Fandoms::DivineCodes
    include Scrappers::Fandoms::DuoHeroes
    include Scrappers::Fandoms::Images
    include Scrappers::Fandoms::LegendaryHeroes
    include Scrappers::Fandoms::MythicHeroes
    include Scrappers::Fandoms::ResplendentHeroes
    include Scrappers::Fandoms::SacredSealCosts
    include Scrappers::Fandoms::Skills
    include Scrappers::Fandoms::SkillsWeapons
    include Scrappers::Fandoms::SummonPool
    include Scrappers::Fandoms::UnitSkills
    include Scrappers::Fandoms::UnitStats
    include Scrappers::Fandoms::Units
    include Scrappers::Fandoms::UnitsFodder
    include Scrappers::Fandoms::Utils

    attr_reader :client, :now, :errors, :logger, :constants

    BATCH_SIZE = 500

    def initialize(level: Logger::ERROR)
      @client = MediawikiApi::Client.new 'https://feheroes.fandom.com/api.php'
      @now = Time.now
      @logger = Logger.new($stdout)
      logger.level = level

      setup_accents_table

      boot
      setup_s3

      super
    end

    def reset!
      boot
    end

    def handle_everything
      log_and_launch(:scrap_everything)
      log_and_launch(:fill_everything)
      # log_and_launch(:export_everything)

      nil
    end

    def scrap_everything
      log_and_launch(:scrap_units)
      log_and_launch(:scrap_unit_stats)
      log_and_launch(:scrap_unit_skills)
      log_and_launch(:scrap_skills)
      log_and_launch(:scrap_sacred_seal_costs)
      log_and_launch(:scrap_duo_heroes)
      # log_and_launch(:scrap_resplendent_heroes) # available in unit properties
      log_and_launch(:scrap_legendary_heroes)
      log_and_launch(:scrap_mythic_heroes)
      log_and_launch(:scrap_generic_summon_pool)
      log_and_launch(:scrap_special_summon_pool)
      log_and_launch(:scrap_divine_codes)
      log_and_launch(:scrap_banner_focuses)
      log_and_launch(:scrap_distributions)

      log_and_launch(:compute_all_seals)

      log_and_launch(:scrap_all_images)

      nil
    end

    def fill_everything
      log_and_launch(:fill_units_with_availabilities)

      log_and_launch(:fill_skills_with_base_id)
      log_and_launch(:fill_skills_with_genealogy)
      log_and_launch(:fill_skills_with_availabilities)
      log_and_launch(:fill_skills_with_prefodder)

      log_and_launch(:fill_units_with_duo_duel_scores)
      log_and_launch(:fill_units_with_legendary_duel_scores)
      log_and_launch(:fill_units_with_skills)
      log_and_launch(:fill_units_with_stats)
      log_and_launch(:fill_units_with_themes)

      log_and_launch(:fill_skills_with_images)
      log_and_launch(:fill_seals_with_images)
      log_and_launch(:fill_units_with_images)

      log_and_launch(:fill_units_with_arena_scores)

      nil
    end

    def export_everything
      log_and_launch(:export_accents)
      log_and_launch(:export_banners)
      log_and_launch(:export_distributions)
      log_and_launch(:export_units)
      log_and_launch(:export_skills)
      log_and_launch(:export_skills_units)
      log_and_launch(:export_seals)

      # must be exported after skills
      log_and_launch(:export_constants)

      nil
    end

    def inspect
      "<#{self.class} @now=#{now}>"
    end

    def export_accents
      export_files(
        'accents.json' => :accents_table,
      )
    end

    def export_constants
      constants.transform_values! { |v| v.is_a?(Array) ? v.sort : v }
      export_files(
        'constants.json' => constants,
      )
    end

    private

    def boot
      @errors = empty_errors
      @constants = {
        skills_max_tier: 0,
        skills_max_sp: 0,
        skills_max_cd: 0,
      }
    end

    def empty_errors
      Hash.new { |h, k| h[k] = [] }
    end

    def retrieve_all_pages(table, fields, limit = BATCH_SIZE)
      pages = []
      offset = 0
      loop do
        logger.warn %{-- querying table "#{table}" (with limit: #{limit}, offset: #{offset})}
        response = client.action(
          :cargoquery,
          tables: table,
          fields: fields.join(','),
          offset:,
          limit:,
        )
        logger.warn "--- number of results : #{response.data.size}"
        break if response.data.empty?

        pages += response.data.map { |d| d['title'] }
        offset += limit
      end
      pages
    end

    def sanitize_name(str)
      return if str.nil?

      str
        .gsub('&quot;', '"')
        .gsub('&amp;', '&')
    end
  end
end
