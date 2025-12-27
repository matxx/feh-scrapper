# frozen_string_literal: true

require 'active_support/core_ext/enumerable'
require 'active_support/core_ext/hash/slice'

# to_date
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/string/conversions'

require 'scrappers/fandoms/units/scores'
require 'scrappers/fandoms/units/themes'

module Scrappers
  module Fandoms
    module Units
      include Scrappers::Fandoms::Units::Scores
      include Scrappers::Fandoms::Units::Themes

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
      UNIT_KIND_CHOSEN = 'CHOSEN'
      UNIT_KIND_LEGENDARY = 'LEGENDARY'
      UNIT_KIND_MYTHIC = 'MYTHIC'
      UNIT_KIND_REARMED = 'REARMED'
      UNIT_KIND_ENTWINED = 'ENTWINED'

      FIVE_STAR_FOCUS_ONLY_UNIT_KINDS = [
        UNIT_KIND_AIDED,
        # UNIT_KIND_ASCENDED,
        UNIT_KIND_ATTUNED,
        UNIT_KIND_EMBLEM,
        UNIT_KIND_CHOSEN,
        UNIT_KIND_LEGENDARY,
        UNIT_KIND_MYTHIC,
        UNIT_KIND_REARMED,
        UNIT_KIND_ENTWINED,
      ].freeze
      # UNIT_TRAITS = [
      #   UNIT_KIND_AIDED,
      #   UNIT_KIND_ASCENDED,
      #   UNIT_KIND_ATTUNED,
      #   UNIT_KIND_EMBLEM,
      #   UNIT_KIND_REARMED,
      #   UNIT_KIND_ENTWINED,
      #   UNIT_KIND_CHOSEN,
      # ].freeze

      UNIT_PROPERTY_BY_KIND = {
        UNIT_KIND_AIDED => 'aided',
        UNIT_KIND_ASCENDED => 'ascended',
        UNIT_KIND_ATTUNED => 'attuned',
        # UNIT_KIND_BRAVE => 'brave',
        UNIT_KIND_DUO => 'duo',
        UNIT_KIND_EMBLEM => 'emblem',
        # UNIT_KIND_FALLEN => 'fallen',
        UNIT_KIND_HARMONIZED => 'harmonized',
        UNIT_KIND_CHOSEN => 'chosen',
        UNIT_KIND_LEGENDARY => 'legendary',
        UNIT_KIND_MYTHIC => 'mythic',
        UNIT_KIND_REARMED => 'rearmed',
        UNIT_KIND_ENTWINED => 'entwined',
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
          unit[:int_id] = unit['IntID'].to_i
          unit[:is_in] = hash_for_is_in
          unit[:lowest_rarity] = hash_for_lowest_rarity
          unit[:divine_codes] = Hash.new { |h, k| h[k] = [] }
          unit[:properties] = (unit['Properties'] || '').split(',')

          if unit[:properties].intersect?(FIVE_STAR_FOCUS_ONLY_UNIT_PROPERTIES) ||
             INT_IDS_OF_FOCUS_ONLY_UNITS.include?(unit[:int_id])
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

          if unit[:divine_codes].key?(:normal)
            unit[:divine_codes][:normal]
              .sort_by! { |desc| [desc[:number], desc[:title], desc[:cost]] }
          end
          if unit[:divine_codes].key?(:limited)
            unit[:divine_codes][:limited]
              .sort_by! { |desc| [desc[:year], desc[:month], desc[:rarity], desc[:cost]] }
          end

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

      INT_ID_ANNIVERSARY_MARTH = 1235
      INT_ID_D_ELINCIA = 1303
      INT_ID_H_B_IKE = 1315
      INT_ID_H_B_LYN = 1316
      INT_IDS_OF_FOCUS_ONLY_UNITS = [
        INT_ID_ANNIVERSARY_MARTH,
        INT_ID_D_ELINCIA,
        INT_ID_H_B_IKE,
        INT_ID_H_B_LYN,
      ].freeze

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
      INT_IDS_OF_TT_UNITS_WITHOUT_THEME = [
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

      def export_units
        export_files(
          'units.json' => :units_as_json,
          'units-availabilities.json' => :unit_availabilities_as_json,
          'units-stats.json' => :unit_stats_as_json,
          'units-stats-ranks.json' => :unit_stats_ranks_as_json,
        )
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
        element =
          if unit[:properties].include?('chosen')
            chosen = all_chosen_heroes_by_pagename[unit['Page']]
            chosen['ChosenEffect']
          elsif unit[:properties].include?('legendary')
            legend = all_legendary_heroes_by_pagename[unit['Page']]
            legend['LegendaryEffect']
          elsif unit[:properties].include?('mythic')
            mythic = all_mythic_heroes_by_pagename[unit['Page']]
            mythic['MythicEffect']
          end

        {
          id: unit['TagID'],
          name: sanitize_name(unit['Name']),
          title: sanitize_name(unit['Title']),
          full_name: sanitize_name(unit['Page']),
          abbreviated_name: abbreviated_name(unit),
          theme: unit[:theme],

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

          is_chosen:     unit[:properties].include?('chosen'),
          is_legendary:  unit[:properties].include?('legendary'),
          is_mythic:     unit[:properties].include?('mythic'),
          element:,

          is_duo:        unit[:properties].include?('duo'),
          is_harmonized: unit[:properties].include?('harmonized'),

          is_rearmed:    unit[:properties].include?('rearmed'),
          is_attuned:    unit[:properties].include?('attuned'),
          is_ascended:   unit[:properties].include?('ascended'),
          is_emblem:     unit[:properties].include?('emblem'),
          is_aided:      unit[:properties].include?('aided'),
          is_entwined:   unit[:properties].include?('entwined'),

          is_refresher:  unit[:properties].include?('refresher'),

          addition_date: unit['AdditionDate'],
          release_date: unit['ReleaseDate'],
          version: unit[:version],
        }.merge(
          unit.slice(
            :game8_id,
            :game8_name,

            :image_url_for_portrait,
            :image_url_for_icon_chosen,
            :image_url_for_icon_legendary,
            :image_url_for_icon_mythic,

            :bst,
            :duel_score,
            :clash_score,
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
            skill = get_skill_from_wikiname(desc['skill'])
            if skill.nil?
              errors[:units_skills_without_skill] << [unit['WikiName'], desc]
              next
            end

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

      def unit_stats_ranks_as_json
        relevant_units.map { |unit| unit_stat_rank_as_json(unit) }
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
            :iv_hp,
            :iv_atk,
            :iv_spd,
            :iv_def,
            :iv_res,
          ),
        )
      end

      NAMES_OF_CHARACTERS_WITH_BOTH_GENDERS = [
        'Alear',
        'Byleth',
        'Corrin',
        'Grima',
        'Kana',
        'Kris',
        'Morgan',
        'Robin',
        'Shez',
      ].freeze

      def unit_stat_rank_as_json(unit)
        {
          id: unit['TagID'],
        }.merge(
          unit.slice(
            :rank_hp,
            :rank_atk,
            :rank_spd,
            :rank_def,
            :rank_res,
            :rank_bst,
          ),
        )
      end

      ABBREVIATED_NAME = {
        INT_ID_ANNIVERSARY_MARTH => '35!Marth',
        INT_ID_D_ELINCIA => 'D!Elincia',
        INT_ID_H_B_IKE => 'H!B!Ike',
        INT_ID_H_B_LYN => 'H!B!Lyn',

        # TODO
        INT_ID_AZURA_YOUNG => 'Azura (Young)',
      }.freeze

      NAME_ABBREVIATIONS = {
        'Black Knight' => 'BK',
      }.freeze

      def abbreviated_name(unit)
        return ABBREVIATED_NAME[unit[:int_id]] if ABBREVIATED_NAME.key?(unit[:int_id])

        name = unit['Name']
        name = NAME_ABBREVIATIONS[name] || name

        if NAMES_OF_CHARACTERS_WITH_BOTH_GENDERS.include?(unit['Name'])
          name = "#{name}(M)" if unit['Gender'].start_with?('M')
          name = "#{name}(F)" if unit['Gender'].start_with?('F')
        end

        # seasonals

        case unit[:theme]
        # recurring
        when self.class::THEME_NEW_YEAR
          return "NY!#{name}"
        when self.class::THEME_DESERT
          return "De!#{name}"
        when self.class::THEME_DOD
          return "V!#{name}"
        when self.class::THEME_SPRING
          return "Sp!#{name}"
        when self.class::THEME_KIDS
          return "Y!#{name}"
        when self.class::THEME_WEDDING
          return "Gr!#{name}" if unit['Gender'].start_with?('M')
          return "Br!#{name}" if unit['Gender'].start_with?('F')

          return "We!#{name}"
        when self.class::THEME_SUMMER
          return "Su!#{name}"
        when self.class::THEME_HALLOWEEN
          return "H!#{name}"
        when self.class::THEME_NINJAS
          return "N!#{name}"
        when self.class::THEME_WINTER
          return "W!#{name}"
        # other
        when self.class::THEME_DANCE
          return "Da!#{name}"
        when self.class::THEME_HOSHIDAN_SUMMER
          return "HSu!#{name}"
        when self.class::THEME_HOSTILE_SPRING
          return "HSp!#{name}"
        when self.class::THEME_PICNIC
          return "Pic!#{name}"
        when self.class::THEME_PIRATES
          return "P!#{name}"
        when self.class::THEME_TEA
          return "T!#{name}"
        when self.class::THEME_TRIBES
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
        return "Et!#{name}" if unit[:properties].include?('entwined')

        return "B!#{name}" if unit[:properties].include?('brave')
        return "F!#{name}" if unit[:properties].include?('fallen')

        return "C!#{name}" if unit[:properties].include?('chosen')
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
          8
        elsif unit['ReleaseDate'] < '2020-08-18' # CYL4
          7
        elsif unit['ReleaseDate'] < '2021-08-17' # CYL5
          6
        elsif unit['ReleaseDate'] < '2022-08-17' # CYL6
          5
        elsif unit['ReleaseDate'] < '2023-08-16' # CYL7
          4
        elsif unit['ReleaseDate'] < '2024-08-16' # CYL8
          3
        elsif unit['ReleaseDate'] < '2025-08-15' # CYL9
          2
        else
          1
        end
      end
    end
  end
end
