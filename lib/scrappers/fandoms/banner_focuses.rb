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

      def export_banners(dirs = self.class::EXPORT_DIRS)
        string = JSON.pretty_generate(banners_as_json)
        dirs.each do |dir|
          file_name = "#{dir}/banners.json"
          FileUtils.mkdir_p File.dirname(file_name)
          File.write(file_name, string)
        end

        nil
      end

      private

      def banners_as_json
        all_banner_focuses_by_pagename.map do |name, rows|
          {
            name: name.gsub('&quot;', '"').gsub('&amp;', '&'),
            unit_ids: rows.map do |row|
              unit = all_units_by_wikiname[row['Unit']]
              if unit.nil?
                @errors[:banner_focus_not_found] << row
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
