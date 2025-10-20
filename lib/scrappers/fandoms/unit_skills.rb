# frozen_string_literal: true

module Scrappers
  module Fandoms
    module UnitSkills
      attr_reader(
        :all_unit_skills,
        :all_unit_skills_by_unit_wikiname,
        :all_unit_skills_by_skill_wikiname,
      )

      SLOT_WEAPON = 'weapon'
      SLOT_ASSIST = 'assist'
      SLOT_SPECIAL = 'special'
      SLOT_A = 'a'
      SLOT_B = 'b'
      SLOT_C = 'c'
      SLOT_S = 's'
      SLOT_X = 'x'

      SKILL_BY_SLOT_BY_WIKI_SLOT = {
        'weapon' => SLOT_WEAPON,
        'assist' => SLOT_ASSIST,
        'special' => SLOT_SPECIAL,
        'passivea' => SLOT_A,
        'passiveb' => SLOT_B,
        'passivec' => SLOT_C,
        'sacredseal' => SLOT_S,
        'passivex' => SLOT_X,
      }.freeze

      def reset_all_unit_skills!
        @all_unit_skills = nil
        @all_unit_skills_by_unit_wikiname = nil
        @all_unit_skills_by_skill_wikiname = nil
      end

      # https://feheroes.fandom.com/wiki/Special:CargoTables/UnitSkills
      def scrap_unit_skills
        return if all_unit_skills

        fields = [
          '_pageName=Page',
          'WikiName',
          'skill',
          'skillPos',
          'defaultRarity',
          'unlockRarity',
        ]
        @all_unit_skills = retrieve_all_pages('UnitSkills', fields)
        @all_unit_skills_by_unit_wikiname  = all_unit_skills.group_by { |x| x['WikiName'] }
        @all_unit_skills_by_skill_wikiname = all_unit_skills.group_by { |x| x['skill'] }

        nil
      end

      def fill_units_with_skills
        all_units.each do |unit|
          unit[:all_unit_skills] = all_unit_skills_by_unit_wikiname[unit['WikiName']].dup
          if unit[:all_unit_skills].nil?
            errors[:units_without_skills] << unit['WikiName'] unless unit['Properties']&.include?('enemy')
            next
          end

          unit[:all_unit_skills].reject! do |unit_skill|
            skill = get_skill_from_wikiname(unit_skill['skill'])
            next false if skill

            errors[:missing_skill] << unit_skill
            true
          end

          unit[:all_unit_skills].sort_by! { |unit_skill| unit_skill['skillPos'].to_i }

          unit[:skills_by_slot] = unit[:all_unit_skills].group_by do |unit_skill|
            skill = get_skill_from_wikiname(unit_skill['skill'])
            wiki_slot = skill['Scategory']
            SKILL_BY_SLOT_BY_WIKI_SLOT[wiki_slot] || wiki_slot
          end
          unit[:original_skills_max_sp_by_slot] = unit[:skills_by_slot].transform_values do |skills|
            skills.map { |unit_skill| get_skill_from_wikiname(unit_skill['skill'])['SP'].to_i }.max
          end

          is_dragon = unit['WeaponType'].include?('Breath')
          has_dc_seal = is_dragon || ['Red Sword', 'Green Axe', 'Blue Lance'].include?(unit['WeaponType'])

          errors[:units_without_weapon] << unit['WikiName'] if unit[:original_skills_max_sp_by_slot][SLOT_WEAPON].nil?

          unit[:skills_max_sp_by_slot] = {
            SLOT_WEAPON => unit[:original_skills_max_sp_by_slot][SLOT_WEAPON] || 0,
            SLOT_ASSIST => 400,
            SLOT_SPECIAL => 500,
            SLOT_A => 300,
            SLOT_B => 300,
            SLOT_C => is_dragon   ? 400 : 300,
            SLOT_S => has_dc_seal ? 300 : 240,
            # SLOT_X => 300,
          }
          unit[:skills_max_sp] = unit[:skills_max_sp_by_slot].values.sum
        end

        nil
      end

      def fill_skills_with_availabilities
        all_skills.each do |skill|
          skill[:fodder_details] = all_unit_skills_by_skill_wikiname[skill['WikiName']]
          skill[:is_in] = hash_for_is_in
          skill[:fodder_lowest_rarity_when_obtained] = hash_for_lowest_rarity
          skill[:fodder_lowest_rarity_for_inheritance] = hash_for_lowest_rarity
          skill[:divine_codes] = Hash.new { |h, k| h[k] = [] }
        end

        all_skills_by_wikiname.each_value do |skill|
          next if skill[:fodder_details].nil?

          missings = skill[:fodder_details].select { |x| all_units_by_wikiname[x['WikiName']].nil? }
          next (errors[:missing_fodder_wikinames] << missings.map { |x| x['WikiName'] }) if missings.any?

          normal_divine_codes  = []
          limited_divine_codes = []

          skill[:fodder_details].each do |fodder_detail|
            unit = all_units_by_wikiname[fodder_detail['WikiName']]

            normal_divine_codes  += unit[:divine_codes][:normal]  if unit[:is_in][:normal_divine_codes]
            limited_divine_codes += unit[:divine_codes][:limited] if unit[:is_in][:limited_divine_codes]

            keys_for_is_in.each do |key|
              next unless unit[:is_in][key]

              skill[:is_in][key] = true

              lowest_rarity = fodder_detail['unlockRarity'].to_i
              if skill[:fodder_lowest_rarity_for_inheritance][key].nil? ||
                 lowest_rarity < skill[:fodder_lowest_rarity_for_inheritance][key]
                skill[:fodder_lowest_rarity_for_inheritance][key] = lowest_rarity
              end

              lowest_rarity = unit[:lowest_rarity][key]
              if skill[:fodder_lowest_rarity_when_obtained][key].nil? ||
                 lowest_rarity < skill[:fodder_lowest_rarity_when_obtained][key]
                skill[:fodder_lowest_rarity_when_obtained][key] = lowest_rarity
              end
            end
          end

          if normal_divine_codes.any?
            skill[:divine_codes][:normal] =
              normal_divine_codes
              .sort_by { |desc| [desc[:number], desc[:title], desc[:cost]] }
          end
          if limited_divine_codes.any?
            skill[:divine_codes][:limited] =
              limited_divine_codes
              .sort_by { |desc| [desc[:number], desc[:title], desc[:cost]] }
          end

          nil
        end

        nil
      end

      def export_skills_units
        export_files(
          'skills_units.json' => :units_skills_as_json,
        )
      end

      private

      def units_skills_as_json
        all_unit_skills.map { |unit_skill| unit_skill_as_json(unit_skill) }.compact
      end

      def unit_skill_as_json(unit_skill)
        unit = all_units_by_wikiname[unit_skill['WikiName']]
        if unit.nil?
          errors[:unit_skill_without_unit] << unit_skill['WikiName']
          return
        end
        return unless relevant_unit?(unit)

        skill = get_skill_from_wikiname(unit_skill['skill'])
        if skill.nil?
          errors[:unit_skill_without_skill] << unit_skill['WikiName']
          return
        end
        return unless relevant_skill?(skill)

        {
          unit_id: unit['TagID'],
          skill_id: skill['TagID'],
          default: unit_skill['defaultRarity'].to_i,
          unlock: unit_skill['unlockRarity'].to_i,
        }
      end
    end
  end
end
