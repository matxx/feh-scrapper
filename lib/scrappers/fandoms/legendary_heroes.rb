# frozen_string_literal: true

module Scrappers
  module Fandoms
    module LegendaryHeroes
      attr_reader(
        :all_legendary_heroes,
        :all_legendary_heroes_by_pagename,
      )

      def reset_all_legendary_heroes!
        @all_legendary_heroes = nil
        @all_legendary_heroes_by_pagename = nil
      end

      # https://feheroes.fandom.com/wiki/Special:CargoTables/LegendaryHero
      def scrap_legendary_heroes
        return if all_legendary_heroes

        fields = [
          '_pageName=Page',
          'LegendaryEffect',
          # 'AllyBoostHP',
          # 'AllyBoostAtk',
          # 'AllyBoostSpd',
          # 'AllyBoostDef',
          # 'AllyBoostRes',
          'Duel',
        ]

        @all_legendary_heroes = retrieve_all_pages('LegendaryHero', fields)
        @all_legendary_heroes_by_pagename =
          all_legendary_heroes
          .index_by { |x| x['Page'] }

        legendary_heroes_with_same_pagename =
          all_legendary_heroes
          .group_by { |x| x['Page'] }
          .select { |_, v| v.size > 1 }
        return if legendary_heroes_with_same_pagename.empty?

        errors[:legendary_heroes_with_same_pagename] = legendary_heroes_with_same_pagename.keys
      end

      def fill_units_with_legendary_duel_scores
        all_legendary_heroes.each do |hero|
          unit = all_units_by_pagename[hero['Page']]
          next (errors[:unknown_legendary_hero] << hero) if unit.nil?

          score = hero['Duel'].to_i
          next if score.zero?

          unit[:duel_score] = score
        end

        nil
      end
    end
  end
end
