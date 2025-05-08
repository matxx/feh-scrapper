# frozen_string_literal: true

module Scrappers
  module Fandoms
    module Distributions
      attr_reader(
        :all_distributions,
      )

      def reset_all_banners!
        @all_distributions = nil
      end

      # https://feheroes.fandom.com/wiki/Special:CargoTables/Distributions
      def scrap_distributions
        return if all_distributions

        fields = [
          '_pageName=Page',
          'Unit',
          'Rarity',
          'Source',
          'Amount',
          'Type',
          'StartTime',
          'EndTime',
        ]

        @all_distributions = retrieve_all_pages('Distributions', fields)

        nil
      end

      def export_distributions(dirs = self.class::EXPORT_DIRS)
        string = JSON.pretty_generate(heroic_grails_as_json)
        dirs.each do |dir|
          file_name = "#{dir}/units-heroic_grails.json"
          FileUtils.mkdir_p File.dirname(file_name)
          File.write(file_name, string)
        end

        nil
      end

      private

      def relevant_heroic_grails
        all_distributions
          .select { |d| d['Type'] == 'Heroic Grails' }
          .sort_by { |d| d['StartTime'] }
      end

      def heroic_grails_as_json
        relevant_heroic_grails.map do |row|
          unit = all_units_by_pagename[row['Unit']]
          if unit.nil?
            @errors[:distribution_unit_not_found] << row
            next
          end

          {
            start_time: row['StartTime'],
            unit_id: unit['TagID'],
          }
        end.compact
      end
    end
  end
end
