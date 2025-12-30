# frozen_string_literal: true

module Scrappers
  module Fandoms
    module Units
      module AbbreviatedNames
        NAMES_OF_CHARACTERS_WITH_BOTH_GENDERS = [
          'Alear',
          'Byleth',
          'Corrin',
          'Grima',
          'Kana',
          'Kris',
          'Morgan',
          'Robin',
          'Shez',
        ].freeze

        ABBREVIATED_NAME = {
          self.class::INT_ID_ANNIVERSARY_MARTH => '35!Marth',
          self.class::INT_ID_D_ELINCIA => 'D!Elincia',
          self.class::INT_ID_H_B_IKE => 'H!B!Ike',
          self.class::INT_ID_H_B_LYN => 'H!B!Lyn',

          self.class::INT_ID_CAMILLA_ADRIFT => 'Ad!Camilla',
          self.class::INT_ID_CORRIN_M_ADRIFT => 'Ad!Corrin(M)',
          self.class::INT_ID_CORRIN_F_ADRIFT => 'Ad!Corrin(F)',
        }.freeze

        NAME_ABBREVIATIONS = {
          'Black Knight' => 'BK',
        }.freeze

        ABBREVIATED_NAME_SUFFIXES = {
          self.class::INT_ID_EIRIKA_TOME => 'Tome',
          self.class::INT_ID_CHROM_CAV => 'Cav',
          self.class::INT_ID_REINHARDT_SWORD => 'Sword',
          self.class::INT_ID_OLWEN_GREEN => 'Green',
          self.class::INT_ID_HINOKA_BOW => 'Bow',
          self.class::INT_ID_NINO_FLYING => 'Fly',
          self.class::INT_ID_OLIVIA_FLYING => 'Fly',

          self.class::INT_ID_MARTH_FE13 => 'FE13',
          self.class::INT_ID_ANNA_FE13 => 'FE13',
          self.class::INT_ID_SELENA_FE8 => 'FE8',
          # self.class::INT_ID_HILDA_FE16 => 'FE16',
          self.class::INT_ID_HILDA_FE4 => 'FE4',
          # self.class::INT_ID_ARTHUR_FE14 => 'FE14',
          self.class::INT_ID_ARTHUR_FE4 => 'FE4',

          self.class::INT_ID_CATRIA_SOV => 'SoV',
          self.class::INT_ID_PALLA_SOV => 'SoV',
          self.class::INT_ID_EST_SOV => 'SoV',
        }.freeze

        def abbreviated_name(unit)
          return self.class::ABBREVIATED_NAME[unit[:int_id]] if self.class::ABBREVIATED_NAME.key?(unit[:int_id])

          name = unit['Name']
          name = self.class::NAME_ABBREVIATIONS[name] || name

          # suffixes

          if self.class::NAMES_OF_CHARACTERS_WITH_BOTH_GENDERS.include?(unit['Name'])
            name = "#{name}(M)" if unit['Gender'].start_with?('M')
            name = "#{name}(F)" if unit['Gender'].start_with?('F')
          end

          name = "#{name}(A)" if self.class::INT_IDS_OF_ADULTS.include?(unit[:int_id])
          name = "#{name}(Y)" if self.class::INT_IDS_OF_YOUNGS.include?(unit[:int_id])

          if self.class::ABBREVIATED_NAME_SUFFIXES.key?(unit[:int_id])
            name = "#{name}(#{self.class::ABBREVIATED_NAME_SUFFIXES[unit[:int_id]]})"
          end

          # prefixes

          ## seasonals

          case unit[:theme]
          ### recurring
          when self.class::THEME_NEW_YEAR
            return "NY!#{name}"
          when self.class::THEME_DESERT
            return "De!#{name}"
          when self.class::THEME_DOD
            return "V!#{name}"
          when self.class::THEME_SPRING
            return "Sp!#{name}"
          when self.class::THEME_KIDS
            return "Y!#{name}"
          when self.class::THEME_WEDDING
            return "Gr!#{name}" if unit['Gender'].start_with?('M')
            return "Br!#{name}" if unit['Gender'].start_with?('F')

            return "We!#{name}"
          when self.class::THEME_SUMMER
            return "Su!#{name}"
          when self.class::THEME_HALLOWEEN
            return "H!#{name}"
          when self.class::THEME_NINJAS
            return "N!#{name}"
          when self.class::THEME_WINTER
            return "W!#{name}"
          ### other
          when self.class::THEME_DANCE
            return "Da!#{name}"
          when self.class::THEME_HOSHIDAN_SUMMER
            return "HSu!#{name}"
          when self.class::THEME_HOSTILE_SPRING
            return "HSp!#{name}"
          when self.class::THEME_PICNIC
            return "Pic!#{name}"
          when self.class::THEME_PIRATES
            return "P!#{name}"
          when self.class::THEME_TEA
            return "T!#{name}"
          when self.class::THEME_THIEVES
            return "Th!#{name}"
          when self.class::THEME_S12
            return "S12!#{name}"
          when self.class::THEME_NATIONS
            return "FT!#{name}" if unit['ReleaseDate']&.start_with?('2022')
            return "WT!#{name}" if unit['ReleaseDate']&.start_with?('2023')
            return "IT!#{name}" if unit['ReleaseDate']&.start_with?('2024')
            return "Fe!#{name}" if unit['ReleaseDate']&.start_with?('2025')
          end

          ## traits

          return "Ai!#{name}" if unit[:properties].include?('aided')
          return "As!#{name}" if unit[:properties].include?('ascended')
          return "At!#{name}" if unit[:properties].include?('attuned')
          return "E!#{name}" if unit[:properties].include?('emblem')
          return "R!#{name}" if unit[:properties].include?('rearmed')
          return "Et!#{name}" if unit[:properties].include?('entwined')

          return "B!#{name}" if unit[:properties].include?('brave')
          return "F!#{name}" if unit[:properties].include?('fallen')

          return "C!#{name}" if unit[:properties].include?('chosen')
          return "L!#{name}" if unit[:properties].include?('legendary')
          return "M!#{name}" if unit[:properties].include?('mythic')

          return "D!#{name}" if unit[:properties].include?('duo')
          return "H!#{name}" if unit[:properties].include?('harmonized')

          name
        end
      end
    end
  end
end
