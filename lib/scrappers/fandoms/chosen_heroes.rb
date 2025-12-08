# frozen_string_literal: true

module Scrappers
  module Fandoms
    module ChosenHeroes
      attr_reader(
        :all_chosen_heroes,
        :all_chosen_heroes_by_pagename,
      )

      def reset_all_chosen_heroes!
        @all_chosen_heroes = nil
        @all_chosen_heroes_by_pagename = nil
      end

      # https://feheroes.fandom.com/wiki/Special:CargoTables/ChosenHero
      def scrap_chosen_heroes
        return if all_chosen_heroes

        fields = [
          '_pageName=Page',
          'ChosenEffect',
          'Clash',
        ]

        @all_chosen_heroes = retrieve_all_pages('ChosenHero', fields)
        @all_chosen_heroes_by_pagename =
          all_chosen_heroes
          .index_by { |x| x['Page'] }

        chosen_heroes_with_same_pagename =
          all_chosen_heroes
          .group_by { |x| x['Page'] }
          .select { |_, v| v.size > 1 }
        return if chosen_heroes_with_same_pagename.empty?

        errors[:chosen_heroes_with_same_pagename] = chosen_heroes_with_same_pagename.keys
      end

      def fill_units_with_chosen_duel_scores
        all_chosen_heroes.each do |hero|
          unit = all_units_by_pagename[hero['Page']]
          next (errors[:unknown_chosen_hero] << hero['Page']) if unit.nil?

          score = hero['Clash'].to_i
          next if score.zero?

          unit[:duel_score] = score
        end

        nil
      end
    end
  end
end
