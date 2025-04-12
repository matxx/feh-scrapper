# frozen_string_literal: true

require 'active_support/core_ext/string/conversions'

module Scrappers
  module Fandoms
    module SummonPool
      attr_reader(
        :generic_summon_pool,
        :current_generic_pool,
        :current_generic_pool_by_unit_pagename,
        :current_generic_pool_by_unit_wikiname,

        :special_summon_pool,
        :special_summon_pool_by_unit_wikiname,
      )

      def reset_generic_summon_pool!
        @generic_summon_pool = nil
        @current_generic_pool = nil
        @current_generic_pool_by_unit_pagename = nil
        @current_generic_pool_by_unit_wikiname = nil
      end

      def reset_special_summon_pool!
        @special_summon_pool = nil
        @special_summon_pool_by_unit_wikiname = nil
      end

      ## retrieve generic summoning pool
      # https://feheroes.fandom.com/wiki/Special:CargoTables/SummoningAvailability
      def scrap_generic_summon_pool
        return if generic_summon_pool

        fields = [
          '_pageName=Page',
          'Rarity',
          'Property',
          'StartTime',
          'EndTime',
        ]
        @generic_summon_pool =
          retrieve_all_pages('SummoningAvailability', fields)
          .map { |x| x.merge(start_time: x['StartTime'].to_time, end_time: x['EndTime'].to_time) }
        @current_generic_pool = generic_summon_pool.select { |x| x[:start_time] < now && now < x[:end_time] }
        @current_generic_pool_by_unit_pagename = current_generic_pool.group_by { |x| x['Page'] }
        @current_generic_pool_by_unit_wikiname = current_generic_pool.group_by { |x| pagename_to_wikiname(x['Page']) }

        nil
      end

      ## retrieve special summoning pool
      # https://feheroes.fandom.com/wiki/Special:CargoTables/SummoningEventFocuses
      def scrap_special_summon_pool
        return if special_summon_pool

        fields = [
          '_pageName=Page',
          'WikiName',
          'Unit',
          'Rarity',
        ]
        @special_summon_pool = retrieve_all_pages('SummoningEventFocuses', fields)
        @special_summon_pool_by_unit_wikiname = special_summon_pool.group_by { |x| x['Unit'] }

        nil
      end
    end
  end
end
