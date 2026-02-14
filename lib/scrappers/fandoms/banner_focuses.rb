# frozen_string_literal: true

module Scrappers
  module Fandoms
    module BannerFocuses
      attr_reader(
        :all_banner_focuses,
        :all_banner_focuses_by_pagename,
      )

      def reset_all_banners!
        @all_banner_focuses = nil
        @all_banner_focuses_by_pagename = nil
      end

      # https://feheroes.fandom.com/wiki/Special:CargoTables/SummoningEventFocuses
      def scrap_banner_focuses
        return if all_banner_focuses

        fields = [
          '_pageName=Page',
          'WikiName',
          'Unit',
          'Rarity',
        ]

        @all_banner_focuses = retrieve_all_pages('SummoningEventFocuses', fields)
        @all_banner_focuses_by_pagename = all_banner_focuses.group_by { |x| x['Page'] }

        nil
      end

      def export_banners
        export_files(
          'banners.json' => :banners_as_json,
        )
      end

      private

      def banners_as_json
        all_banner_focuses_by_pagename.map do |name, rows|
          sanitized_name =
            name
            .gsub('&quot;', '"')
            .gsub('&amp;', '&')
            .gsub('A Monstrous Harvest', 'Treat Fiends') # banner has been renamed after its first appearance
          {
            name: sanitized_name,
            unit_ids: rows.map do |row|
              unit = all_units_by_wikiname[row['Unit']]
              if unit.nil?
                @errors[:unit_on_banner_focus_not_found] << row
                next
              end

              unit['TagID']
            end.uniq.compact.sort,
          }
        end
      end
    end
  end
end
