# frozen_string_literal: true

module Scrappers
  module Fandoms
    module Units
      module Themes
        THEME_NEW_YEAR = :new_year
        THEME_DESERT = :desert
        THEME_DOD = :dod # day of devotion / valentines
        THEME_SPRING = :spring
        THEME_KIDS = :kids
        THEME_WEDDING = :wedding
        THEME_SUMMER = :summer
        THEME_HALLOWEEN = :halloween
        THEME_NINJAS = :ninjas
        THEME_WINTER = :winter
        THEME_DANCE = :dance
        THEME_HOSHIDAN_SUMMER = :hs
        THEME_HOSTILE_SPRING = :hostile_spring
        THEME_PICNIC = :picnic
        THEME_PIRATES = :pirates
        THEME_TEE = :tee
        THEME_TRIBES = :tribes

        # https://feheroes.fandom.com/wiki/Module:SpecialHeroList#L-8
        def fill_units_with_themes
          all_units.each do |unit|
            unit[:int_id] = unit['IntID'].to_i
            next (unit[:theme] = THEME_NEW_YEAR) if unit[:int_id] == INT_ID_NY_CORRIN

            next if !unit[:properties].include?('special') && !unit[:properties].include?('tempest')

            if unit['ReleaseDate'].blank?
              errors[:units_without_release_date] << unit['WikiName'] unless unit['Properties']&.include?('enemy')
              next
            end

            unit[:theme] = nil
            next if self.class::INT_IDS_OF_FOCUS_ONLY_UNITS.include?(unit[:int_id])
            next if unit[:properties].include?('tempest') && unit['ReleaseDate'] < '2018-01'
            next if self.class::INT_IDS_OF_TT_UNITS_WITHOUT_THEME.include?(unit[:int_id])

            year, month, day = unit['ReleaseDate'].split('-').map(&:to_i)

            unit[:theme] =
              # recurring
              if (month == 12 && day >= 25) || (month == 1 && day <= 5)
                THEME_NEW_YEAR
              elsif year >= 2021 && month == 1 && day > 5
                THEME_DESERT
              elsif month == 2
                THEME_DOD
              elsif month == 3
                THEME_SPRING
              elsif year >= 2020 && month == 4
                THEME_KIDS
              elsif month == 5
                THEME_WEDDING
              elsif [6, 7].include?(month)
                THEME_SUMMER
              elsif month == 10
                THEME_HALLOWEEN
              elsif year >= 2020 && month == 11
                THEME_NINJAS
              elsif month == 12 && day < 25
                THEME_WINTER
              # other
              elsif [2017, 2019, 2020].include?(year) && month == 9
                THEME_DANCE
              elsif [2018, 2024].include?(year) && month == 8
                THEME_HOSHIDAN_SUMMER
              elsif [2023, 2025].include?(year) && month == 8
                THEME_TEE
              elsif year == 2019 && month == 1 && day > 5
                THEME_HOSTILE_SPRING
              elsif year == 2019 && month == 4
                THEME_PICNIC
              elsif [2020, 2021].include?(year) && month == 8
                THEME_PIRATES
              elsif [2022, 2023, 2024].include?(year) && month == 9
                THEME_TRIBES
              end
          end
        end
      end
    end
  end
end
