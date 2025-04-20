# frozen_string_literal: true

module Scrappers
  module Fandoms
    module ResplendentHeroes
      attr_reader(
        :all_resplendent_heroes,
        :all_resplendent_heroes_by_pagename,
      )

      def reset_all_resplendent_heroes!
        @all_resplendent_heroes = nil
        @all_resplendent_heroes_by_pagename = nil
      end

      # https://feheroes.fandom.com/wiki/Special:CargoTables/ResplendentHero
      def scrap_resplendent_heroes
        return if all_resplendent_heroes

        fields = [
          '_pageName=Page',
          # 'Unit',
          # 'StartTime',
          # 'EndTime',
          # 'Artist',
          # 'ActorEN',
        ]

        @all_resplendent_heroes = retrieve_all_pages('ResplendentHero', fields)
        @all_resplendent_heroes_by_pagename =
          all_resplendent_heroes
          .index_by { |x| x['Page'] }

        resplendent_heroes_with_same_pagename =
          all_resplendent_heroes
          .group_by { |x| x['Page'] }
          .select { |_, v| v.size > 1 }
        return if resplendent_heroes_with_same_pagename.empty?

        errors[:resplendent_heroes_with_same_pagename] = resplendent_heroes_with_same_pagename.keys
      end
    end
  end
end
