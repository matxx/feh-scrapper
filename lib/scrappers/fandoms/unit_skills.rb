# frozen_string_literal: true

module Scrappers
  module Fandoms
    module UnitSkills
      attr_reader(
        :all_unit_skills,
        :all_unit_skills_by_unit_wikiname,
        :all_unit_skills_by_skill_name,
      )

      SLOT_WEAPON = 'weapon'
      SLOT_ASSIST = 'assist'
      SLOT_SPECIAL = 'special'
      SLOT_A = 'a'
      SLOT_B = 'b'
      SLOT_C = 'c'
      SLOT_S = 's'
      SLOT_X = 'x'

      SLOTS_FOR_SCORE = [
        SLOT_WEAPON,
        SLOT_ASSIST,
        SLOT_SPECIAL,
        SLOT_A,
        SLOT_B,
        SLOT_C,
        SLOT_S,
      ].freeze

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

      # exceptions are dealt with later
      MAX_INHERITABLE_SP_COST = {
        SLOT_WEAPON => 350, # refined arcane weapons
        SLOT_ASSIST => 400,
        SLOT_SPECIAL => 500,
        SLOT_A => 300,
        SLOT_B => 400,
        SLOT_C => 300,
        SLOT_S => 240,
      }.freeze

      def reset_all_unit_skills!
        @all_unit_skills = nil
        @all_unit_skills_by_unit_wikiname = nil
        @all_unit_skills_by_skill_wikiname = nil
        @all_unit_skills_by_skill_name = nil
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
          'additionDate',
        ]
        @all_unit_skills = retrieve_all_pages('UnitSkills', fields)
        @all_unit_skills_by_unit_wikiname = all_unit_skills.group_by { |x| x['WikiName'] }
        @all_unit_skills_by_skill_name = all_unit_skills.group_by { |x| x['skill'] }

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
          is_melee = self.class::ALL_MELEE.include?(unit['WeaponType'])
          has_dc_seal = is_dragon || is_melee

          errors[:units_without_weapon] << unit['WikiName'] if unit[:original_skills_max_sp_by_slot][SLOT_WEAPON].nil?

          unit[:skills_max_sp_by_slot] = {}
          SLOTS_FOR_SCORE.each do |slot|
            # original unit skill
            # (deals with PRF weapons & Chrom PRF assists skills which are the only "500 SP" assist skills)
            original_skill_max_sp = unit[:original_skills_max_sp_by_slot][slot] || 0

            max_inheritable_sp_cost =
              if slot == SLOT_S && has_dc_seal
                300
              else
                MAX_INHERITABLE_SP_COST[slot]
              end

            unit[:skills_max_sp_by_slot][slot] = [original_skill_max_sp, max_inheritable_sp_cost].max
          end

          unit[:skills_max_sp] = unit[:skills_max_sp_by_slot].values.sum
        end

        nil
      end

      def fill_skills_with_availabilities
        all_skills.each do |skill|
          skill[:owner_details]   = all_unit_skills_by_skill_name[skill['WikiName']]
          skill[:owner_details] ||= all_unit_skills_by_skill_name[skill_pagename_to_wikiname(skill['Name'])]
          skill[:is_in] = hash_for_is_in
          skill[:owner_lowest_rarity_when_obtained] = hash_for_lowest_rarity
          skill[:owner_lowest_rarity_for_inheritance] = hash_for_lowest_rarity
          skill[:divine_codes] = Hash.new { |h, k| h[k] = [] }
        end

        all_skills_by_wikiname.each_value do |skill|
          next if skill[:owner_details].nil?

          missings = skill[:owner_details].select { |x| all_units_by_wikiname[x['WikiName']].nil? }
          next (errors[:missing_owner_wikinames] << missings.map { |x| x['WikiName'] }) if missings.any?

          normal_divine_codes  = []
          limited_divine_codes = []

          skill[:owner_details].each do |owner_detail|
            unit = all_units_by_wikiname[owner_detail['WikiName']]

            normal_divine_codes  += unit[:divine_codes][:normal]  if unit[:is_in][:normal_divine_codes]
            limited_divine_codes += unit[:divine_codes][:limited] if unit[:is_in][:limited_divine_codes]

            keys_for_is_in.each do |key|
              next unless unit[:is_in][key]

              skill[:is_in][key] = true

              lowest_rarity = owner_detail['unlockRarity'].to_i
              if skill[:owner_lowest_rarity_for_inheritance][key].nil? ||
                 lowest_rarity < skill[:owner_lowest_rarity_for_inheritance][key]
                skill[:owner_lowest_rarity_for_inheritance][key] = lowest_rarity
              end

              lowest_rarity = unit[:lowest_rarity][key]
              if skill[:owner_lowest_rarity_when_obtained][key].nil? ||
                 lowest_rarity < skill[:owner_lowest_rarity_when_obtained][key]
                skill[:owner_lowest_rarity_when_obtained][key] = lowest_rarity
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
              .sort_by { |desc| [desc[:year], desc[:month], desc[:rarity], desc[:cost]] }
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
