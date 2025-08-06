# frozen_string_literal: true

module Scrappers
  module Fandoms
    module VersionUpdates
      attr_reader(
        :all_version_updates,
        :sorted_version_updates,
      )

      def reset_all_version_updates!
        @all_version_updates = nil
        @sorted_version_updates = nil
      end

      # https://feheroes.fandom.com/wiki/Special:CargoTables/VersionUpdates
      def scrap_version_updates
        return if all_version_updates

        fields = [
          # '_pageName=Page',
          # 'Version',
          'Major',
          'Minor',
          # 'Patch',
          'ReleaseTime',
          # 'Notification',
          # 'PreviewNotification',
        ]

        @all_version_updates = retrieve_all_pages('VersionUpdates', fields)
        @all_version_updates.each do |version|
          version[:release_time] = version['ReleaseTime'].to_time
          version[:release_date] = version[:release_time].to_date
          version[:version] = "#{version['Major']}.#{version['Minor']}"
        end
        @sorted_version_updates = @all_version_updates.sort_by do |version|
          version[:release_time]
        end.reverse

        nil
      end

      def fill_units_with_versions
        all_units.each do |unit|
          if unit['ReleaseDate'].nil?
            errors[:units_without_release_date] << unit['WikiName'] unless unit['Properties']&.include?('enemy')
            next
          end

          unit[:release_date] = unit['ReleaseDate'].to_date
          v = sorted_version_updates.find { |v| v[:release_date] <= unit[:release_date] }
          if v.nil?
            errors[:units_without_version] << unit['WikiName']
            next
          end

          unit[:version] = v[:version]
        end
      end
    end
  end
end
