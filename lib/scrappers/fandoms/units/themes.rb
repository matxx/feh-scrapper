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
        THEME_TEA = :tea
        THEME_THIEVES = :thieves
        THEME_S12 = :s12
        THEME_NATIONS = :nations

        # https://feheroes.fandom.com/wiki/Module:SpecialHeroList#L-8
        def fill_units_with_themes
          all_units.each do |unit|
            unit[:int_id] = unit['IntID'].to_i
            next (unit[:theme] = THEME_NEW_YEAR) if unit[:int_id] == self.class::INT_ID_NY_CORRIN

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
              elsif month == 1 && year >= 2021 && day > 5
                THEME_DESERT
              elsif month == 2
                THEME_DOD
              elsif month == 3
                THEME_SPRING
              elsif month == 4 && year >= 2020
                THEME_KIDS
              elsif month == 5
                THEME_WEDDING
              elsif [6, 7].include?(month)
                THEME_SUMMER
              elsif month == 10
                THEME_HALLOWEEN
              elsif month == 11 && year >= 2020
                THEME_NINJAS
              elsif month == 12 && day < 25
                THEME_WINTER
              # other
              elsif [2017, 2019, 2020].include?(year) && month == 9
                THEME_DANCE
              elsif month == 8 && [2018, 2024].include?(year)
                THEME_HOSHIDAN_SUMMER
              elsif month == 8 && [2023, 2025].include?(year)
                THEME_TEA
              elsif month == 8 && [2022].include?(year)
                THEME_THIEVES
              elsif month == 1 && year == 2019 && day > 5
                THEME_HOSTILE_SPRING
              elsif month == 4 && year == 2019
                THEME_PICNIC
              elsif month == 8 && [2020, 2021].include?(year)
                THEME_PIRATES
              elsif month == 9 && year == 2021
                THEME_S12
              elsif month == 9 && [2022, 2023, 2024, 2025].include?(year)
                THEME_NATIONS
              end
          end
        end
      end
    end
  end
end
