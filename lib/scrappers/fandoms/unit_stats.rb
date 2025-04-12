# frozen_string_literal: true

module Scrappers
  module Fandoms
    module UnitStats
      attr_reader(
        :all_unit_stats,
        :all_unit_stats_by_wikiname,
        :all_unit_stats_by_pagename,
      )

      # https://feheroes.fandom.com/wiki/Superassets_and_Superflaws
      SUPERBOON_GROWTH_RATES = [25, 45, 70, 90].freeze
      SUPERBANE_GROWTH_RATES = [30, 50, 75, 95].freeze

      def reset_all_unit_stats!
        @all_unit_stats = nil
        @all_unit_stats_by_wikiname = nil
        @all_unit_stats_by_pagename = nil
      end

      # https://feheroes.fandom.com/wiki/Special:CargoTables/UnitStats
      def scrap_unit_stats
        return if all_unit_stats

        fields = [
          '_pageName=Page',
          'WikiName',
          'Lv1HP5',
          'Lv1Atk5',
          'Lv1Spd5',
          'Lv1Def5',
          'Lv1Res5',
          'HPGR3',
          'AtkGR3',
          'SpdGR3',
          'DefGR3',
          'ResGR3',
        ]

        @all_unit_stats = retrieve_all_pages('UnitStats', fields)
        @all_unit_stats_by_wikiname = all_unit_stats.index_by { |x| x['WikiName'] }
        @all_unit_stats_by_pagename = all_unit_stats.index_by { |x| x['Page'] }

        unit_stats_with_same_wikiname =
          all_unit_stats
          .group_by { |x| x['WikiName'] }
          .select { |_, v| v.size > 1 }
          .reject { |k, _| k.include?('Kiran') } # stats depends on weapon
        # https://feheroes.fandom.com/wiki/Kiran:_Hero_Summoner
        if unit_stats_with_same_wikiname.any?
          errors[:unit_stats_with_same_wikiname] << unit_stats_with_same_wikiname.keys
        end

        nil
      end

      # https://feheroes.fandom.com/wiki/Stat_growth
      def fill_units_with_stats
        all_unit_stats.each do |unit_stat|
          unit = all_units_by_wikiname[unit_stat['WikiName']]
          next (errors[:unit_stats_without_unit] << unit_stat) if unit.nil?

          unit[:level1_hp]  = unit_stat['Lv1HP5'].to_i
          unit[:level1_atk] = unit_stat['Lv1Atk5'].to_i
          unit[:level1_spd] = unit_stat['Lv1Spd5'].to_i
          unit[:level1_def] = unit_stat['Lv1Def5'].to_i
          unit[:level1_res] = unit_stat['Lv1Res5'].to_i

          unit[:growth_rate_hp]  = unit_stat['HPGR3'].to_i
          unit[:growth_rate_atk] = unit_stat['AtkGR3'].to_i
          unit[:growth_rate_spd] = unit_stat['SpdGR3'].to_i
          unit[:growth_rate_def] = unit_stat['DefGR3'].to_i
          unit[:growth_rate_res] = unit_stat['ResGR3'].to_i

          growth_rates = [
            unit[:growth_rate_hp],
            unit[:growth_rate_atk],
            unit[:growth_rate_spd],
            unit[:growth_rate_def],
            unit[:growth_rate_res],
          ]
          unit[:has_superboon] = growth_rates.intersect?(SUPERBOON_GROWTH_RATES)

          unit[:level40_hp]  = level40_stat_from_unit_stats(unit_stat, 'HP')
          unit[:level40_atk] = level40_stat_from_unit_stats(unit_stat, 'Atk')
          unit[:level40_spd] = level40_stat_from_unit_stats(unit_stat, 'Spd')
          unit[:level40_def] = level40_stat_from_unit_stats(unit_stat, 'Def')
          unit[:level40_res] = level40_stat_from_unit_stats(unit_stat, 'Res')

          unit[:iv_hp]  = iv_from_unit_stat(unit_stat, 'HP')
          unit[:iv_atk] = iv_from_unit_stat(unit_stat, 'Atk')
          unit[:iv_spd] = iv_from_unit_stat(unit_stat, 'Spd')
          unit[:iv_def] = iv_from_unit_stat(unit_stat, 'Def')
          unit[:iv_res] = iv_from_unit_stat(unit_stat, 'Res')

          unit[:bst] = bst_from_unit_stats(unit)
        end

        @constants[:units_count] = relevant_units.size

        [
          'hp',
          'atk',
          'spd',
          'def',
          'res',
        ].each do |stat|
          current_stat = nil
          current_rank = nil
          relevant_units
            .sort_by { |unit| unit[:"level40_#{stat}"] }
            .reverse
            .each_with_index do |unit, index|
              if current_stat.nil? || unit[:"level40_#{stat}"] < current_stat
                current_rank = index + 1
                current_stat = unit[:"level40_#{stat}"]
              end

              unit[:"rank_#{stat}"] = current_rank
              next if current_rank > 1

              @constants[:"units_max_#{stat}"] ||= unit[:"level40_#{stat}"]
              @constants[:"units_max_#{stat}_ids"] ||= []
              @constants[:"units_max_#{stat}_ids"] << unit['TagID']
            end
        end

        current_bst = nil
        current_rank = nil
        relevant_units
          .sort_by { |unit| unit[:bst] }
          .reverse
          .each_with_index do |unit, index|
            if current_bst.nil? || unit[:bst] < current_bst
              current_rank = index + 1
              current_bst = unit[:bst]
            end

            unit[:rank_bst] = current_rank
            next if current_rank > 1

            @constants[:units_max_bst] ||= unit[:bst]
            @constants[:units_max_bst_ids] ||= []
            @constants[:units_max_bst_ids] << unit['TagID']
          end

        nil
      end

      def iv_from_unit_stat(unit_stat, stat)
        growth_rate = unit_stat["#{stat}GR3"].to_i
        return 'bane' if SUPERBANE_GROWTH_RATES.include?(growth_rate)
        return 'boon' if SUPERBOON_GROWTH_RATES.include?(growth_rate)

        nil
      end

      def level40_stat_from_unit_stats(unit_stat, stat)
        lvl1_stat   = unit_stat["Lv1#{stat}5"].to_i
        growth_rate = unit_stat["#{stat}GR3"].to_i

        old_level = 1
        new_level = 40
        rarity = 5
        growth_value = ((new_level - old_level) * (growth_rate * (0.79 + (0.07 * rarity))).floor / 100).floor
        # (outer `floor` being useless here because of ruby integer division)

        lvl1_stat + growth_value
      end

      def bst_from_unit_stats(unit)
        0 +
          unit[:level40_hp] +
          unit[:level40_atk] +
          unit[:level40_spd] +
          unit[:level40_def] +
          unit[:level40_res] +
          0
      end
    end
  end
end
