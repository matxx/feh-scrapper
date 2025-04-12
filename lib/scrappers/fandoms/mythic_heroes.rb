# frozen_string_literal: true

module Scrappers
  module Fandoms
    module MythicHeroes
      attr_reader(
        :all_mythic_heroes,
        :all_mythic_heroes_by_pagename,
      )

      def reset_all_mythic_heroes!
        @all_mythic_heroes = nil
        @all_mythic_heroes_by_pagename = nil
      end

      # https://feheroes.fandom.com/wiki/Special:CargoTables/MythicHero
      def scrap_mythic_heroes
        return if all_mythic_heroes

        fields = [
          '_pageName=Page',
          'MythicEffect',
          'MythicEffect2',
          'MythicEffect3',
          # 'AllyBoostHP',
          # 'AllyBoostAtk',
          # 'AllyBoostSpd',
          # 'AllyBoostDef',
          # 'AllyBoostRes',
        ]

        @all_mythic_heroes = retrieve_all_pages('MythicHero', fields)
        @all_mythic_heroes_by_pagename =
          all_mythic_heroes
          .index_by { |x| x['Page'] }

        mythic_heroes_with_same_pagename =
          all_mythic_heroes
          .group_by { |x| x['Page'] }
          .select { |_, v| v.size > 1 }
        return if mythic_heroes_with_same_pagename.empty?

        errors[:mythic_heroes_with_same_pagename] = mythic_heroes_with_same_pagename.keys
      end
    end
  end
end
