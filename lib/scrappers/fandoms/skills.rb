# frozen_string_literal: true

module Scrappers
  module Fandoms
    module Skills
      WEAPON = 'weapon'
      SACRED_SEAL = 'sacredseal'

      # as long as "all_skills_by_name" is only used for seals
      # there is no problem with those
      KNOW_SKILLS_WITH_SAME_NAME = [
        'Falchion',
        'Missiletainn',
        'Rallying Cry',
        'Umbra Burst',
      ].freeze

      attr_reader(
        :all_skills,
        :all_skills_by_wikiname,
        :all_skills_grouped_by_name,
        :all_skills_by_name,

        :seals_from_skills,
        :seals_from_skills_by_name,
      )

      def reset_all_skills!
        @all_skills = nil
        @all_skills_by_wikiname = nil
        @all_skills_grouped_by_name = nil
        @all_skills_by_name = nil

        @seals_from_skills = nil
        @seals_from_skills_by_name = nil

        reset_cached_skills!
      end

      def reset_cached_skills!
        @relevant_skills = nil
        @relevant_skills_without_refine = nil
      end

      # https://feheroes.fandom.com/wiki/Special:CargoTables/Skills
      # more details
      # https://feheroes.fandom.com/wiki/Template:Passive
      def scrap_skills
        return if all_skills

        fields = [
          'GroupName',
          'Name',
          'WikiName',
          'TagID',
          'Scategory',
          # 'UseRange',
          'Icon',
          'RefinePath', # atk|def|res|spd|skill1|skill2|skill1atk|skill2atk
          'Description',
          'Required',
          # 'Next',
          # 'PromotionRarity',
          # 'PromotionTier',
          'Exclusive',
          'SP',
          'CanUseMove',
          'CanUseWeapon',
          # 'Might',
          # 'StatModifiers',
          'Cooldown',
          'WeaponEffectiveness',
          # 'SkillBuildCost',
          # 'Properties',
        ]
        skills = retrieve_all_pages('Skills', fields)
        seals, others = skills.partition { |s| s['Scategory'] == self.class::SACRED_SEAL }
        @seals_from_skills = seals
        @all_skills = others

        @all_skills_by_wikiname = all_skills.index_by { |x| x['WikiName'] }
        @all_skills_grouped_by_name = all_skills.group_by { |x| x['Name'] }
        @all_skills_by_name =
          all_skills
          .reject { |x| x['RefinePath'] }
          .index_by { |x| x['Name'] }

        skills_with_same_wikiname = all_skills.group_by { |x| x['WikiName'] }.select { |_, v| v.size > 1 }
        errors[:skills_with_same_wikiname] = skills_with_same_wikiname.keys if skills_with_same_wikiname.any?

        skills_with_same_name =
          all_skills
          .reject { |x| x['RefinePath'] }
          .group_by { |x| x['Name'] }
          .select { |_, v| v.size > 1 }
        true_skills_with_same_name = skills_with_same_name.keys - KNOW_SKILLS_WITH_SAME_NAME
        errors[:skills_with_same_name] = true_skills_with_same_name if true_skills_with_same_name.any?

        @seals_from_skills_by_name = seals_from_skills.index_by { |x| x['Name'] }
        seals_with_same_name =
          seals_from_skills
          .group_by { |x| x['Name'] }
          .select { |_, v| v.size > 1 }
        errors[:seals_with_same_name] = seals_with_same_name.keys if seals_with_same_name.any?

        nil
      end

      def fill_skills_with_base_id
        all_skills.each do |skill|
          next if skill['RefinePath'].nil?
          next (errors[:skill_without_tag_id] << skill['WikiName']) if skill['TagID'].nil?

          # 3 letter with refine path are concatenated to the ID :
          # https://feheroes.fandom.com/wiki/Template:Weapon_Infobox?action=edit
          # (line ~50)
          # or weird caracters for skill refines
          # Obsidian Lance: "SID_黒曜の槍_一"
          # Bull Blade: "SID_猛牛の剣_連"
          # Taguel Fang: "SID_タグエルの爪牙2_一"
          skill[:base_id] = skill['TagID'].gsub(/_[A-Z]{3}\Z/, '').gsub(/2?_[^_]\Z/, '')
        end
      end

      def fill_skills_with_genealogy
        all_skills.each do |skill|
          next if skill['Required'].nil?

          skill[:downgrades_wikinames] = skill['Required'].split(';')
          skill[:downgrades_wikinames].each do |downgrade_wikiname|
            downgrade = all_skills_by_wikiname[downgrade_wikiname]
            downgrade[:upgrades_wikinames] ||= Set.new
            downgrade[:upgrades_wikinames].add(skill['WikiName'])
          end
        end

        # rubocop:disable Style/CombinableLoops
        # this loop needs all the downgrades/upgrades to be filled,
        # so it can not be combined with previous loop
        all_skills.each do |skill|
          next if skill['Required']

          rec_fill_tier(skill, 1)
        end
        # rubocop:enable Style/CombinableLoops

        nil
      end

      def export_skills(dirs = self.class::EXPORT_DIRS)
        string = JSON.pretty_generate(skills_as_json)
        dirs.each do |dir|
          file_name = "#{dir}/skills.json"
          FileUtils.mkdir_p File.dirname(file_name)
          File.write(file_name, string)
        end

        string = JSON.pretty_generate(skill_descriptions_as_json)
        dirs.each do |dir|
          file_name = "#{dir}/skills-descriptions.json"
          FileUtils.mkdir_p File.dirname(file_name)
          File.write(file_name, string)
        end

        string = JSON.pretty_generate(skill_availabilities_as_json)
        dirs.each do |dir|
          file_name = "#{dir}/skills-availabilities.json"
          FileUtils.mkdir_p File.dirname(file_name)
          File.write(file_name, string)
        end

        nil
      end

      def relevant_skill?(skill)
        # do not export captain skills
        return false if skill['Scategory'] == 'captain'
        # do not export enemy only skills
        return false if skill[:fodder_details]&.all? { |desc| desc['WikiName'].include?('ENEMY') }
        # only export refines with effect
        return false unless [nil, 'skill1', 'skill2'].include?(skill['RefinePath'])
        # do not export "Røkkr Sieges" skills
        return false if skill[:fodder_details].nil? && skill[:base_id].nil? && skill['Required'].nil?

        true
      end

      def relevant_skills
        @relevant_skills ||= all_skills.select { |skill| relevant_skill?(skill) }
      end

      def relevant_skills_without_refine
        @relevant_skills_without_refine ||=
          relevant_skills
          .select { |skill| skill['RefinePath'].nil? }
      end

      private

      def rec_fill_tier(skill, tier)
        skill[:tier] = tier
        return if skill[:upgrades_wikinames].nil?

        skill[:upgrades_wikinames].each do |skill_wikiname|
          rec_fill_tier(all_skills_by_wikiname[skill_wikiname], tier + 1)
        end
      end

      def skills_as_json
        relevant_skills.map { |skill| skill_as_json(skill) }
      end

      def skill_as_json(skill)
        tier = skill[:tier]
        sp = skill['SP'].to_i
        cd = skill['Cooldown'] == '-1' ? nil : skill['Cooldown'].to_i

        constants[:skills_max_tier] = tier if constants[:skills_max_tier] < tier
        constants[:skills_max_sp] = sp if constants[:skills_max_sp] < sp
        constants[:skills_max_cd] = cd if cd && constants[:skills_max_cd] < cd

        res = {
          id: skill['TagID'],
          base_id: skill[:base_id],
          game8_id: skill[:game8_id],
          name: sanitize_name(skill['Name']),
          group_name: sanitize_name(skill['GroupName']),
          category: skill['Scategory'],
          weapon_type: sanitize_weapon_type(skill),

          image_url: skill[:image_url],

          is_prf: skill['Exclusive'] == '1',
          sp:,
          tier:,
          refine: skill['RefinePath'],

          cd:,
          eff: skill['WeaponEffectiveness']&.split(','),

          restrictions: {
            moves: sanitize_move_restriction(skill),
            weapons: sanitize_weapon_restriction(skill),
          },
        }

        if skill[:upgrades_wikinames]
          res[:upgrade_ids] = skill[:upgrades_wikinames].map do |name|
            upgrade = all_skills_by_wikiname[name]
            next (errors[:skills_upgrades_without_skill] << [skill['WikiName'], name]) if upgrade.nil?

            upgrade['TagID']
          end.compact
        end
        if skill[:downgrades_wikinames]
          res[:downgrade_ids] = skill[:downgrades_wikinames].map do |name|
            downgrade = all_skills_by_wikiname[name]
            next (errors[:skills_downgrades_without_skill] << [skill['WikiName'], name]) if downgrade.nil?

            downgrade['TagID']
          end.compact
        end

        res.compact
      end

      MOVE_I = 'Infantry'
      MOVE_A = 'Armored'
      MOVE_C = 'Cavalry'
      MOVE_F = 'Flying'
      ALL_MOVES = [
        MOVE_I,
        MOVE_A,
        MOVE_C,
        MOVE_F,
      ].freeze

      def sanitize_move_restriction(skill, prefix = :skill)
        can_use = skill['CanUseMove'].split(/,[[:space:]]*/)
        can_use.uniq!

        errors[:"#{prefix}_with_unknown_move_restrictions"] << skill['WikiName'] if (can_use - ALL_MOVES).any?

        case can_use.length
        when 1, 2
          { can_use: }
        when 3
          { can_not_use: ALL_MOVES - can_use }
        when 4
          { none: true }
        else
          errors[:"#{prefix}_with_weird_move_restrictions"] << skill['WikiName']
          {}
        end
      end

      def skill_descriptions_as_json
        relevant_skills.map { |skill| skill_description_as_json(skill) }
      end

      def skill_description_as_json(skill)
        {
          id: skill['TagID'],
          description: sanitize_description(skill['Description']),
        }
      end

      def sanitize_description(desc)
        return if desc.nil?

        desc
          .gsub('&quot;', '"')
          .gsub('&lt;', '<')
          .gsub('&gt;', '>')
          .gsub('&amp;', '&')
          # must be after `&amp;` transformer
          # used to make lists easier to see
          # ex : https://feheroes.fandom.com/wiki/C_Time_Traveler
          .gsub('&nbsp;', '')
      end

      def skill_availabilities_as_json
        relevant_skills.map { |skill| skill_availability_as_json(skill) }
      end

      def skill_availability_as_json(skill)
        fodder_ids = []
        skill[:fodder_details]&.each do |u|
          unit = all_units_by_wikiname[u['WikiName']]
          next (errors[:fodder_not_found] << u['WikiName']) if unit.nil?

          fodder_ids << unit['TagID']
        end

        {
          id: skill['TagID'],

          fodder_ids:,
          fodder: skill[:prefodder].transform_values { |n| [1, n].max },
          is_in: obfuscate_keys(skill[:is_in]),
          self.class::OBFUSCATED_KEYS[:fodder_lowest_rarity_when_obtained] =>
            obfuscate_keys(skill[:fodder_lowest_rarity_when_obtained].compact),
          self.class::OBFUSCATED_KEYS[:fodder_lowest_rarity_for_inheritance] =>
            obfuscate_keys(skill[:fodder_lowest_rarity_for_inheritance].compact),
          divine_codes: skill[:divine_codes],
        }
      end
    end
  end
end
