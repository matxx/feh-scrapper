# frozen_string_literal: true

module Scrappers
  module Fandoms
    module EmblemHeroes
      attr_reader(
        :all_emblem_heroes,
        :all_emblem_heroes_by_pagename,
      )

      def reset_all_emblem_heroes!
        @all_emblem_heroes = nil
        @all_emblem_heroes_by_pagename = nil
      end

      # https://feheroes.fandom.com/wiki/Special:CargoTables/EmblemHero
      def scrap_emblem_heroes
        return if all_emblem_heroes

        fields = [
          '_pageName=Page',
          'Effect',
          'Icon',
          # 'WikiPerson',
          # 'WikiSecondPerson',
          # 'WikiThirdPerson',
        ]

        @all_emblem_heroes = retrieve_all_pages('EmblemHero', fields)
        @all_emblem_heroes_by_pagename = all_emblem_heroes.index_by { |x| x['Page'] }

        emblem_heroes_with_same_pagename =
          all_emblem_heroes.group_by { |x| x['Page'] }.select { |_, v| v.size > 1 }
        if emblem_heroes_with_same_pagename.any?
          errors[:emblem_heroes_with_same_pagename] = emblem_heroes_with_same_pagename.keys
        end

        nil
      end
    end
  end
end
