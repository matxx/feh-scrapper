# frozen_string_literal: true

module Scrappers
  module Fandoms
    module Distributions
      attr_reader(
        :all_distributions,
        :all_heroic_grails,
        :all_heroic_grails_by_pagename,
      )

      def reset_all_distributions!
        @all_distributions = nil
        @all_heroic_grails = nil
        @all_heroic_grails_by_pagename = nil
      end

      # https://feheroes.fandom.com/wiki/Use_Heroic_Grails
      # https://feheroes.fandom.com/wiki/Special:CargoTables/Distributions
      def scrap_distributions
        return if all_distributions

        fields = [
          # '_pageName=Page',
          'Unit',
          'Rarity',
          # 'Source',
          # 'Amount', # [1, 2, 20]
          'Type', # ["Automatic", "Heroic Grails", "Log-In", "Map", "Purchase", "Quest", "Story", "Tempest Trials"]
          'StartTime',
          # 'EndTime',
        ]

        @all_distributions = retrieve_all_pages('Distributions', fields)
        @all_heroic_grails = all_distributions.select { |d| d['Type'] == 'Heroic Grails' }

        @all_heroic_grails_by_pagename = @all_heroic_grails.group_by { |x| x['Unit'] }
        hgs_with_same_pagename = all_heroic_grails.group_by { |x| x['Unit'] }.select { |_, v| v.size > 1 }
        errors[:hgs_with_same_pagename] = hgs_with_same_pagename.keys if hgs_with_same_pagename.any?

        nil
      end

      def export_distributions
        export_files(
          'units-heroic_grails.json' => :heroic_grails_as_json,
        )
      end

      private

      def heroic_grails_as_json
        all_heroic_grails
          .sort_by { |d| [d['StartTime'], d['TagID']] }
          .map do |row|
            unit = all_units_by_pagename[row['Unit']]
            if unit.nil?
              @errors[:distribution_unit_not_found] << row
              next
            end

            {
              start_time: row['StartTime'],
              unit_id: unit['TagID'],
              rarity: row['Rarity'].to_i,
            }
          end.compact
      end
    end
  end
end
