# frozen_string_literal: true

require 'active_support/core_ext/enumerable'
require 'active_support/core_ext/hash/slice'

module Scrappers
  module Fandoms
    module Units
      attr_reader(
        :all_units,
        :all_units_by_wikiname,
        :all_units_grouped_by_pagename,
        :all_units_by_pagename,
      )

      def reset_all_units!
        @all_units = nil
        @all_units_by_wikiname = nil
        @all_units_grouped_by_pagename = nil
        @all_units_by_pagename = nil
        @relevant_units = nil
      end

      UNIT_KIND_AIDED = 'AIDED'
      UNIT_KIND_ASCENDED = 'ASCENDED'
      UNIT_KIND_ATTUNED = 'ATTUNED'
      # UNIT_KIND_BRAVE = 'BRAVE'
      UNIT_KIND_DUO = 'DUO'
      UNIT_KIND_EMBLEM = 'EMBLEM'
      # UNIT_KIND_FALLEN = 'FALLEN'
      UNIT_KIND_HARMONIZED = 'HARMONIZED'
      UNIT_KIND_LEGENDARY = 'LEGENDARY'
      UNIT_KIND_MYTHIC = 'MYTHIC'
      UNIT_KIND_REARMED = 'REARMED'

      FIVE_STAR_FOCUS_ONLY_UNIT_KINDS = [
        UNIT_KIND_AIDED,
        # UNIT_KIND_ASCENDED,
        UNIT_KIND_ATTUNED,
        UNIT_KIND_EMBLEM,
        UNIT_KIND_LEGENDARY,
        UNIT_KIND_MYTHIC,
        UNIT_KIND_REARMED,
      ].freeze
      UNIT_TRAITS = [
        UNIT_KIND_AIDED,
        UNIT_KIND_ASCENDED,
        UNIT_KIND_ATTUNED,
        UNIT_KIND_EMBLEM,
        UNIT_KIND_REARMED,
      ].freeze

      UNIT_PROPERTY_BY_KIND = {
        UNIT_KIND_AIDED => 'aided',
        UNIT_KIND_ASCENDED => 'ascended',
        UNIT_KIND_ATTUNED => 'attuned',
        # UNIT_KIND_BRAVE => 'brave',
        UNIT_KIND_DUO => 'duo',
        UNIT_KIND_EMBLEM => 'emblem',
        # UNIT_KIND_FALLEN => 'fallen',
        UNIT_KIND_HARMONIZED => 'harmonized',
        UNIT_KIND_LEGENDARY => 'legendary',
        UNIT_KIND_MYTHIC => 'mythic',
        UNIT_KIND_REARMED => 'rearmed',
        # 'refresher'
        # 'tempest'
        # 'ghb'
        # 'resplendent'
        # 'special'
      }.freeze
      FIVE_STAR_FOCUS_ONLY_UNIT_PROPERTIES =
        UNIT_PROPERTY_BY_KIND
        .select { |k, _| FIVE_STAR_FOCUS_ONLY_UNIT_KINDS.include?(k) }
        .values

      # https://feheroes.fandom.com/wiki/Special:CargoTables/Units
      # more details on properties
      # https://feheroes.fandom.com/wiki/Template:Hero_Infobox#List_of_properties
      def scrap_units
        return if all_units

        fields = [
          '_pageName=Page',
          'Name',
          'Title',
          'WikiName',
          'Person',
          'Origin',
          'Entries',
          'GameSort',
          'CharSort',
          'TagID',
          'IntID',
          'Gender',
          'WeaponType',
          'MoveType',
          'GrowthMod',
          'Artist',
          'ActorEN',
          'ActorJP',
          'AdditionDate',
          'ReleaseDate',
          'Properties',
          'Description',
        ]

        @all_units = retrieve_all_pages('Units', fields)
        @all_units_by_wikiname =
          all_units
          .index_by { |x| x['WikiName'] }
        @all_units_grouped_by_pagename =
          all_units
          .group_by { |x| x['Page'] }
        @all_units_by_pagename =
          all_units
          .reject { |unit| unit['Properties']&.include?('enemy') }
          .index_by { |x| x['Page'] }

        units_with_same_wikiname = all_units.group_by { |x| x['WikiName'] }.select { |_, v| v.size > 1 }
        errors[:units_with_same_wikiname] = units_with_same_wikiname.keys if units_with_same_wikiname.any?

        units_with_same_pagename =
          all_units
          .reject { |unit| unit['Properties']&.include?('enemy') }
          .group_by { |x| x['Page'] }
          .select { |_, v| v.size > 1 }
        errors[:units_with_same_pagename] = units_with_same_pagename.keys if units_with_same_pagename.any?

        nil
      end

      # TODO: ? extract units received as rewards
      # https://feheroes.fandom.com/wiki/Special:CargoTables/Distributions

      # some usage examples :
      # https://feheroes.fandom.com/wiki/Module:HeroListByAvailability
      # https://feheroes.fandom.com/wiki/Module:HeroUtil
      # https://feheroes.fandom.com/wiki/Template:GeneralSummonRarities?action=edit
      def fill_units_with_availabilities
        all_units.each do |unit|
          unit[:is_in] = hash_for_is_in
          unit[:lowest_rarity] = hash_for_lowest_rarity
          unit[:divine_codes] = Hash.new { |h, k| h[k] = [] }
          unit[:properties] = (unit['Properties'] || '').split(',')

          if unit[:properties].intersect?(FIVE_STAR_FOCUS_ONLY_UNIT_PROPERTIES)
            unit[:is_in][:focus_only] = true
            unit[:lowest_rarity][:focus_only] = 5
          elsif unit[:properties].include?('ghb')
            unit[:is_in][:heroic_grails] = true
            unit[:lowest_rarity][:heroic_grails] = 3
          elsif unit[:properties].include?('tempest')
            unit[:is_in][:heroic_grails] = true
            unit[:lowest_rarity][:heroic_grails] = 4
          end
        end

        current_generic_pool_by_unit_wikiname.each do |wikiname, rows|
          unit = all_units_by_wikiname[wikiname]
          next (errors[:missing_units_for_generic_summon_pool] << wikiname) if unit.nil?

          properties = unit[:properties]
          next if properties.include?('enemy')
          next if properties.include?('story')

          if properties.intersect?(FIVE_STAR_FOCUS_ONLY_UNIT_PROPERTIES)
            errors[:focus_only_unit_in_generic_summon_pool] << unit['WikiName']
            next
          end

          if properties.include?('special')
            unit[:is_in][:special_summon_pool] = true
            rarities = rows.map do |row|
              if row['Rarity'] == '5' && row['Property'] == 'SHSpecialRate'
                4.5
              else
                row['Rarity'].to_i
              end
            end
            unit[:lowest_rarity][:special_summon_pool] = rarities.min
            next
          end

          unit[:is_in][:generic_summon_pool] = true
          rarities = rows.map do |row|
            if row['Rarity'] == '5' && row['Property'] == 'specialRate'
              4.5
            else
              row['Rarity'].to_i
            end
          end
          unit[:lowest_rarity][:generic_summon_pool] = rarities.min
        end

        special_summon_pool_by_unit_wikiname.each do |wikiname, rows|
          unit = all_units_by_wikiname[wikiname]
          next (errors[:missing_units_for_special_summon_pool] << wikiname) if unit.nil?

          # some units are in the focus events
          # but not special
          next unless unit[:properties].include?('special')

          unit[:is_in][:special_summon_pool] = true
          unit[:lowest_rarity][:special_summon_pool] ||= rows.map { |r| r['Rarity'].to_i }.min
        end

        divine_codes_by_unit_wikiname.each do |wikiname, rows|
          unit = all_units_by_wikiname[wikiname]
          next (errors[:missing_units_for_divine_codes] << wikiname) if unit.nil?

          rows.each do |row|
            case row[:kind]
            when :normal
              unit[:is_in][:normal_divine_codes] = true
              unit[:lowest_rarity][:normal_divine_codes] = row[:rarity]
              unit[:divine_codes][:normal] << row.slice(:number, :title, :cost)
            when :limited
              unit[:is_in][:limited_divine_codes] = true
              unit[:lowest_rarity][:limited_divine_codes] = row[:rarity]
              unit[:divine_codes][:limited] << row.slice(:year, :month, :rarity, :cost)
            else
              errors[:divine_code_with_weird_kind] << wikiname
            end
          end
        end

        # some more validation
        all_units.each do |unit|
          wikiname = unit['WikiName']

          unit[:lowest_rarity_summon] =
            unit[:lowest_rarity]
            .slice(:generic_summon_pool, :special_summon_pool, :heroic_grails, :focus_only)
            .values
            .compact
            .min

          if unit[:is_in][:special_summon_pool] && unit[:lowest_rarity][:special_summon_pool].nil?
            errors[:special_units_without_rarities] << wikiname
          end
          if unit[:lowest_rarity][:special_summon_pool] && !unit[:properties].include?('special')
            errors[:units_in_special_pool_without_property_special] << wikiname
          end
        end

        nil
      end

      RARITY_1 = 1
      RARITY_2 = 2
      RARITY_3 = 3
      RARITY_4 = 4
      RARITY_5 = 5
      ARENA_SCORES_CONSTANTS = {
        RARITY_1 => {
          base_value: 47,
          level_factor: 68 / 39.0,
        },
        RARITY_2 => {
          base_value: 49,
          level_factor: 73 / 39.0,
        },
        RARITY_3 => {
          base_value: 51,
          level_factor: 79 / 39.0,
        },
        RARITY_4 => {
          base_value: 53,
          level_factor: 84 / 39.0,
        },
        RARITY_5 => {
          base_value: 55,
          level_factor: 7 / 3.0,
        },
      }.freeze

      # formula :
      # https://imgur.com/NycQzxt
      # other resources :
      # https://www.arcticsilverfox.com/score_calc/
      # https://feheroes.fandom.com/wiki/Fire_Emblem_Heroes_Wiki:Arena_score_tier_list
      # https://www.reddit.com/r/FireEmblemHeroes/comments/19atxtw/what_is_the_formula_for_calculating_arena_score/
      # https://www.reddit.com/r/OrderOfHeroes/comments/7ihbqv/the_most_accurate_arena_score_calculator_to_date/
      # https://docs.google.com/spreadsheets/d/1XF8AtQPzAIhyyW_fHHsbBd-Z2jWZM2rBwSkhWy8YeWk/edit?gid=1351020164#gid=1351020164
      def fill_units_with_arena_scores
        rarity_base_value   = ARENA_SCORES_CONSTANTS[RARITY_5][:base_value]
        rarity_level_factor = ARENA_SCORES_CONSTANTS[RARITY_5][:level_factor]
        level = 40
        team_base_score = 150

        all_units.each do |unit|
          total_skill_sp = unit[:skills_max_sp]
          if total_skill_sp.nil?
            errors[:units_without_skills2] << unit['WikiName'] unless unit['Properties']&.include?('enemy')
            next
          end

          merges_count = unit[:properties].include?('story') ? 0 : 10
          unit[:visible_bst] = unit[:duel_score] || unit[:bst]
          unit[:visible_bst] += (unit[:has_superboon] ? 4 : 3) if merges_count.positive?
          unit[:visible_bst] = 180 if unit[:visible_bst] < 180

          total_bst = unit[:visible_bst]
          max_score =
            rarity_base_value +
            (rarity_level_factor * level).floor +
            (merges_count * 2) +
            (total_skill_sp / 100).floor +
            (total_bst / 5).floor

          logger.debug "-- #{unit['WikiName']}"
          logger.debug "rarity_base_value: #{rarity_base_value}"
          logger.debug "rarity_level_factor: #{rarity_level_factor}"
          logger.debug "level: #{level}"
          logger.debug "merges_count : #{merges_count}"
          logger.debug "total_skill_sp: #{total_skill_sp}"
          logger.debug "total_bst: #{total_bst}"

          logger.debug "rarity part : #{rarity_base_value}"
          logger.debug "level part : #{(rarity_level_factor * level).floor}"
          logger.debug "merges part : #{merges_count * 2}"
          logger.debug "skills part : #{(total_skill_sp / 100).floor}"
          logger.debug "bst part : #{(total_bst / 5).floor}"

          logger.debug "max_score : #{(team_base_score + max_score) * 2}"

          unit[:max_score] = (team_base_score + max_score) * 2
        end
      end

      THEME_NEW_YEAR = :new_year
      THEME_DESERT = :desert
      THEME_DOD = :dod # day of devotion / valentines
      THEME_SPRING = :spring
      THEME_KIDS = :kids
      THEME_WEDDING = :wedding
      THEME_SUMMER = :summer
      THEME_HALLOWEEN = :halloween
      THEME_NINJAS = :ninjas
      THEME_WINTER = :winter
      THEME_DANCE = :dance
      THEME_HOSHIDAN_SUMMER = :hs
      THEME_HOSTILE_SPRING = :hostile_spring
      THEME_PICNIC = :picnic
      THEME_PIRATES = :pirates
      THEME_TRIBES = :tribes

      ANNIVERSARY_MARTH_INT_ID = 1235
      INT_ID_NY_CORRIN = 200

      INT_ID_MARISA = 212
      INT_ID_GEROME = 228
      INT_ID_FINN = 238
      INT_ID_CANAS = 258
      INT_ID_ETHLYN = 288
      INT_ID_AZURA_YOUNG = 312
      INT_ID_SIGRUN = 415
      INT_ID_BRUNNYA = 452
      INT_ID_ITSUKI = 480
      INT_IDS_OF_TT_UNITS_WITHOUT_THEMED = [
        INT_ID_MARISA,
        INT_ID_GEROME,
        INT_ID_FINN,
        INT_ID_CANAS,
        INT_ID_ETHLYN,
        INT_ID_AZURA_YOUNG,
        INT_ID_SIGRUN,
        INT_ID_BRUNNYA,
        INT_ID_ITSUKI,
      ].freeze

      # https://feheroes.fandom.com/wiki/Module:SpecialHeroList#L-8
      def fill_units_with_themes
        all_units.each do |unit|
          unit[:int_id] = unit['IntID'].to_i
          next (unit[:theme] = THEME_NEW_YEAR) if unit[:int_id] == INT_ID_NY_CORRIN

          next if !unit[:properties].include?('special') && !unit[:properties].include?('tempest')

          if unit['ReleaseDate'].nil?
            errors[:units_without_release_date] << unit['WikiName'] unless unit['Properties']&.include?('enemy')
            next
          end

          unit[:theme] = nil
          next if unit[:int_id] == ANNIVERSARY_MARTH_INT_ID
          next if unit[:properties].include?('tempest') && unit['ReleaseDate'] < '2018-01'
          next if INT_IDS_OF_TT_UNITS_WITHOUT_THEMED.include?(unit[:int_id])

          year, month, day = unit['ReleaseDate'].split('-').map(&:to_i)

          unit[:theme] =
            # recurring
            if (month == 12 && day >= 25) || (month == 1 && day <= 5)
              THEME_NEW_YEAR
            elsif year >= 2021 && month == 1 && day > 5
              THEME_DESERT
            elsif month == 2
              THEME_DOD
            elsif month == 3
              THEME_SPRING
            elsif year >= 2020 && month == 4
              THEME_KIDS
            elsif month == 5
              THEME_WEDDING
            elsif [6, 7].include?(month)
              THEME_SUMMER
            elsif month == 10
              THEME_HALLOWEEN
            elsif year >= 2020 && month == 11
              THEME_NINJAS
            elsif month == 12 && day < 25
              THEME_WINTER
            # other
            elsif [2017, 2019, 2020].include?(year) && month == 9
              THEME_DANCE
            elsif [2018, 2024].include?(year) && month == 8
              THEME_HOSHIDAN_SUMMER
            elsif year == 2019 && month == 1 && day > 5
              THEME_HOSTILE_SPRING
            elsif year == 2019 && month == 4
              THEME_PICNIC
            elsif [2020, 2021].include?(year) && month == 8
              THEME_PIRATES
            elsif year >= 2021 && month == 9
              THEME_TRIBES
            end
        end
      end

      def export_units(dirs = self.class::EXPORT_DIRS)
        string = JSON.pretty_generate(units_as_json)
        dirs.each do |dir|
          file_name = "#{dir}/units.json"
          FileUtils.mkdir_p File.dirname(file_name)
          File.write(file_name, string)
        end

        string = JSON.pretty_generate(unit_availabilities_as_json)
        dirs.each do |dir|
          file_name = "#{dir}/units-availabilities.json"
          FileUtils.mkdir_p File.dirname(file_name)
          File.write(file_name, string)
        end

        string = JSON.pretty_generate(unit_stats_as_json)
        dirs.each do |dir|
          file_name = "#{dir}/units-stats.json"
          FileUtils.mkdir_p File.dirname(file_name)
          File.write(file_name, string)
        end

        nil
      end

      def relevant_unit?(unit)
        return false if unit[:properties].include?('enemy')

        true
      end

      def relevant_units
        @relevant_units ||= all_units.select { |unit| relevant_unit?(unit) }
      end

      private

      def units_as_json
        relevant_units.map { |unit| unit_as_json(unit) }
      end

      DRAGONFLOWERS_MULTIPLICATOR = 5

      def unit_as_json(unit)
        {
          id: unit['TagID'],
          name: sanitize_name(unit['Name']),
          title: sanitize_name(unit['Title']),
          full_name: sanitize_name(unit['Page']),
          abbreviated_name: abbreviated_name(unit),
          # theme: unit[:theme],

          gender: unit['Gender'],
          move_type: unit['MoveType'],
          weapon_type: unit['WeaponType'],
          games: (unit['Origin'] || '').split(','),

          # game_sort: unit['GameSort'],
          # char_sort: unit['CharSort'],
          id_int: unit[:int_id],
          origin: "#{unit['GameSort'].to_s.rjust(2, '0')}#{unit['CharSort'].to_s.rjust(10, '0')}",
          book: unit_book(unit),
          max_df: DRAGONFLOWERS_MULTIPLICATOR * max_dragonflowers(unit),

          # has_resplendent: !all_resplendent_heroes_by_pagename[unit['Page']].nil?,
          has_respl: unit[:properties].include?('resplendent'),

          is_brave:  unit[:properties].include?('brave'),
          is_fallen: unit[:properties].include?('fallen'),

          is_story:   unit[:properties].include?('story'),
          is_tt:      unit[:properties].include?('tempest'),
          is_ghb:     unit[:properties].include?('ghb'),
          is_special: unit[:properties].include?('special'),
          is_generic_pool: unit[:is_in][:generic_summon_pool],

          is_legendary:  unit[:properties].include?('legendary'),
          is_mythic:     unit[:properties].include?('mythic'),

          is_duo:        unit[:properties].include?('duo'),
          is_harmonized: unit[:properties].include?('harmonized'),

          is_rearmed:    unit[:properties].include?('rearmed'),
          is_attuned:    unit[:properties].include?('attuned'),
          is_ascended:   unit[:properties].include?('ascended'),
          is_emblem:     unit[:properties].include?('emblem'),
          is_aided:      unit[:properties].include?('aided'),

          is_refresher:  unit[:properties].include?('refresher'),

          addition_date: unit['AdditionDate'],
          release_date: unit['ReleaseDate'],
        }.merge(
          unit.slice(
            :game8_id,
            :game8_name,

            :image_url_for_portrait,
            :image_url_for_icon_legendary,
            :image_url_for_icon_mythic,

            :bst,
            :duel_score,
            :visible_bst,
            :max_score,
          ),
        ).compact
      end

      def unit_book(unit)
        id = unit['IntID'].to_i
        return 9 if id >= 1174 # Rune: Source of Wisdom
        return 8 if id >= 1029 # Ratatoskr: Mending Hand
        return 7 if id >= 882 # Seiðr: Goddess of Hope
        return 6 if id >= 738 # Ash: Retainer to Askr
        return 5 if id >= 594 # Reginn: Bearing Hope
        return 4 if id >= 454 # Peony: Sweet Dream
        return 3 if id >= 317 # Eir: Merciful Death
        return 2 if id >= 191 # Fjorm: Princess of Ice

        1
      end

      def unit_availabilities_as_json
        relevant_units.map { |unit| unit_availability_as_json(unit) }
      end

      def unit_availability_as_json(unit)
        {
          id: unit['TagID'],

          is_in: obfuscate_keys(unit[:is_in]),
          lowest_rarity: obfuscate_keys(unit[:lowest_rarity].compact),
          skill_ids: unit[:all_unit_skills].map do |desc|
            skill = all_skills_by_wikiname[desc['skill']]
            next (errors[:units_skills_without_skill] << [unit['WikiName'], desc]) if skill.nil?

            skill['TagID']
          end.compact.sort,
        }.merge(
          unit.slice(
            :divine_codes,
          ),
        ).compact
      end

      def unit_stats_as_json
        relevant_units.map { |unit| unit_stat_as_json(unit) }
      end

      # do not compact
      def unit_stat_as_json(unit)
        {
          id: unit['TagID'],
        }.merge(
          unit.slice(
            :level1_hp,
            :level1_atk,
            :level1_spd,
            :level1_def,
            :level1_res,
            :growth_rate_hp,
            :growth_rate_atk,
            :growth_rate_spd,
            :growth_rate_def,
            :growth_rate_res,
            :level40_hp,
            :level40_atk,
            :level40_spd,
            :level40_def,
            :level40_res,
            :rank_hp,
            :rank_atk,
            :rank_spd,
            :rank_def,
            :rank_res,
            :rank_bst,
            :iv_hp,
            :iv_atk,
            :iv_spd,
            :iv_def,
            :iv_res,
          ),
        )
      end

      def abbreviated_name(unit)
        return '35!Marth' if unit[:int_id] == ANNIVERSARY_MARTH_INT_ID
        return 'Azura (Young)' if unit[:int_id] == INT_ID_AZURA_YOUNG

        name = unit['Name']
        name = 'BK' if name == 'Black Knight'
        name = "#{name}(M)" if unit[:game8_name]&.end_with?(' (M)')
        name = "#{name}(F)" if unit[:game8_name]&.end_with?(' (F)')

        # seasonals

        case unit[:theme]
        # recurring
        when THEME_NEW_YEAR
          return "NY!#{name}"
        when THEME_DESERT
          # return "De!#{name}"
          return "D!#{name}"
        when THEME_DOD
          return "V!#{name}"
        when THEME_SPRING
          return "Sp!#{name}"
        when THEME_KIDS
          return "Y!#{name}"
        when THEME_WEDDING
          return "Br!#{name}"
          # return "We!#{name}"
        when THEME_SUMMER
          return "Su!#{name}"
        when THEME_HALLOWEEN
          return "H!#{name}"
        when THEME_NINJAS
          return "N!#{name}"
        when THEME_WINTER
          return "W!#{name}"
        # other
        when THEME_DANCE
          return "Da!#{name}"
        when THEME_HOSHIDAN_SUMMER
          return "HSu!#{name}"
        when THEME_HOSTILE_SPRING
          return "HSp!#{name}"
        when THEME_PICNIC
          return "Pic!#{name}"
        when THEME_PIRATES
          return "P!#{name}"
        when THEME_TRIBES
          return "FT!#{name}" if unit['ReleaseDate']&.start_with?('2022')
          return "WT!#{name}" if unit['ReleaseDate']&.start_with?('2023')
          return "IT!#{name}" if unit['ReleaseDate']&.start_with?('2024')
        end

        # others

        return "Ai!#{name}" if unit[:properties].include?('aided')
        return "As!#{name}" if unit[:properties].include?('ascended')
        return "At!#{name}" if unit[:properties].include?('attuned')
        return "E!#{name}" if unit[:properties].include?('emblem')
        return "R!#{name}" if unit[:properties].include?('rearmed')

        return "B!#{name}" if unit[:properties].include?('brave')
        return "F!#{name}" if unit[:properties].include?('fallen')

        return "L!#{name}" if unit[:properties].include?('legendary')
        return "M!#{name}" if unit[:properties].include?('mythic')

        # return "D!#{name}" if unit[:properties].include?('duo')
        # return "H!#{name}" if unit[:properties].include?('harmonized')

        # TODO: handle Tiki Young/Adult

        unit[:game8_name] || name
      end

      # B!Eirika & P!Hinoka have same version 5.8 but different max DF
      # => diff between release dates (and not versions)
      # https://feheroes.fandom.com/wiki/Module:MaxStatsTable#L-61
      def max_dragonflowers(unit)
        # version 3.2
        if unit['ReleaseDate'] < '2019-02-07' && unit['MoveType'] == self.class::MOVE_I
          7
        elsif unit['ReleaseDate'] < '2020-08-18' # CYL4
          6
        elsif unit['ReleaseDate'] < '2021-08-17' # CYL5
          5
        elsif unit['ReleaseDate'] < '2022-08-17' # CYL6
          4
        elsif unit['ReleaseDate'] < '2023-08-16' # CYL7
          3
        elsif unit['ReleaseDate'] < '2024-08-16' # CYL8
          2
        else
          1
        end
      end
    end
  end
end
