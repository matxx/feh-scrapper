# frozen_string_literal: true

module Scrappers
  module Fandoms
    module DuoHeroes
      attr_reader(
        :all_duo_heroes,
        :all_duo_heroes_by_pagename,
      )

      def reset_all_duo_heroes!
        @all_duo_heroes = nil
        @all_duo_heroes_by_pagename = nil
      end

      # https://feheroes.fandom.com/wiki/Special:CargoTables/DuoHero
      def scrap_duo_heroes
        return if all_duo_heroes

        fields = [
          '_pageName=Page',
          'DuoSkill',
          # 'WikiSecondPerson',
          # 'WikiThirdPerson',
          'Duel',
        ]

        @all_duo_heroes = retrieve_all_pages('DuoHero', fields)
        @all_duo_heroes_by_pagename = all_duo_heroes.index_by { |x| x['Page'] }

        duo_heroes_with_same_pagename =
          all_duo_heroes.group_by { |x| x['Page'] }.select { |_, v| v.size > 1 }
        if duo_heroes_with_same_pagename.any?
          errors[:duo_heroes_with_same_pagename] = duo_heroes_with_same_pagename.keys
        end

        nil
      end

      def fill_units_with_duo_duel_scores
        all_duo_heroes.each do |hero|
          unit = all_units_by_pagename[hero['Page']]
          next (errors[:unknown_duo_hero] << hero['Page']) if unit.nil?

          unit[:duel_score] = hero['Duel'].to_i
        end

        nil
      end
    end
  end
end
