# frozen_string_literal: true

module Scrappers
  module Fandoms
    module HarmonizedHeroes
      attr_reader(
        :all_harmonized_heroes,
        :all_harmonized_heroes_by_pagename,
      )

      def reset_all_harmonized_heroes!
        @all_harmonized_heroes = nil
        @all_harmonized_heroes_by_pagename = nil
      end

      # https://feheroes.fandom.com/wiki/Special:CargoTables/HarmonizedHero
      def scrap_harmonized_heroes
        return if all_harmonized_heroes

        fields = [
          '_pageName=Page',
          'HarmonizedSkill',
          # 'WikiSecondPerson',
          # 'WikiThirdPerson',
        ]

        @all_harmonized_heroes = retrieve_all_pages('HarmonizedHero', fields)
        @all_harmonized_heroes_by_pagename = all_harmonized_heroes.index_by { |x| x['Page'] }

        harmonized_heroes_with_same_pagename =
          all_harmonized_heroes.group_by { |x| x['Page'] }.select { |_, v| v.size > 1 }
        if harmonized_heroes_with_same_pagename.any?
          errors[:harmonized_heroes_with_same_pagename] = harmonized_heroes_with_same_pagename.keys
        end

        nil
      end
    end
  end
end
