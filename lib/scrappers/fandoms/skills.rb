# frozen_string_literal: true

module Scrappers
  module Fandoms
    module Skills
      # categories
      ## from fandom
      SKILL_CAT_WEAPON = 'weapon'
      SKILL_CAT_SPECIAL = 'special'
      SKILL_CAT_PASSIVE_X = 'passivex'
      SKILL_CAT_SACRED_SEAL = 'sacredseal'
      SKILL_CAT_CAPTAIN = 'captain'
      ## custom
      SKILL_CAT_DUO = 'duo'
      SKILL_CAT_HARMONIZED = 'harmonized'
      SKILL_CAT_EMBLEM = 'emblem'

      # move types
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
        :all_skills_by_tag_id,

        :seals_from_skills,
        :seals_from_skills_by_name,
      )

      def reset_all_skills!
        @all_skills = nil
        @all_skills_by_wikiname = nil
        @all_skills_grouped_by_name = nil
        @all_skills_by_name = nil
        @all_skills_by_tag_id = nil

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
          'UseRange',
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
          'Might',
          # 'StatModifiers',
          'Cooldown',
          'WeaponEffectiveness',
          # 'SkillBuildCost',
          'Properties',
        ]
        skills = retrieve_all_pages('Skills', fields)
        # when a seal exists as a skill, it is not listed in the "Skills" table
        # it only appears in "SacredSealCosts" table
        seals, others = skills.partition { |s| s['Scategory'] == self.class::SKILL_CAT_SACRED_SEAL }
        @seals_from_skills = seals
        @all_skills = others

        @all_skills_by_wikiname = all_skills.index_by { |x| x['WikiName'] }
        @all_skills_grouped_by_name = all_skills.group_by { |x| x['Name'] }
        @all_skills_by_name =
          all_skills
          .reject { |x| x['RefinePath'].present? }
          .index_by { |x| x['Name'] }

        skills_with_same_wikiname = all_skills.group_by { |x| x['WikiName'] }.select { |_, v| v.size > 1 }
        errors[:skills_with_same_wikiname] = skills_with_same_wikiname.keys if skills_with_same_wikiname.any?

        skills_with_same_name =
          all_skills
          .reject { |x| x['RefinePath'].present? }
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

        @all_skills_by_tag_id = all_skills.index_by { |x| x['TagID'] }
        skills_with_same_tag_id =
          all_skills
          .reject { |x| x['Scategory'] == SKILL_CAT_CAPTAIN }
          .group_by { |x| x['TagID'] }
          .select { |_, v| v.size > 1 }
        errors[:skills_with_same_tag_id] = skills_with_same_tag_id.keys if skills_with_same_tag_id.any?

        nil
      end

      def fill_skills_with_base_id
        all_skills.each do |skill|
          next if skill['RefinePath'].blank?
          next (errors[:skill_without_tag_id] << skill['WikiName']) if skill['TagID'].nil?

          # 3 letter with refine path are concatenated to the ID :
          # https://feheroes.fandom.com/wiki/Template:Weapon_Infobox?action=edit
          # (line ~50)
          # or weird caracters for skill refines
          # Obsidian Lance: "SID_黒曜の槍_一"
          # Bull Blade: "SID_猛牛の剣_連"
          # Taguel Fang: "SID_タグエルの爪牙2_一"
          base_id = skill['TagID'].gsub(/2?_[A-Z]{3}\Z/, '').gsub(/2?_[^_]\Z/, '')
          skill[:base_id] = base_id

          base = all_skills_by_tag_id[base_id]
          next (errors[:base_skill_not_found] << [skill['WikiName'], base_id]) if base.nil?

          base[:refine_ids] ||= []
          base[:refine_ids] << skill['TagID']
        end
      end

      def fill_skills_with_genealogy
        all_skills.each do |skill|
          next if skill['Required'].blank?

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
          next if skill['Required'].present?

          rec_fill_skill_tier(skill, 1)
        end
        # rubocop:enable Style/CombinableLoops

        nil
      end

      def export_skills
        export_files(
          'skills.json' => :skills_as_json,
          'skills-descriptions.json' => :skill_descriptions_as_json,
          'skills-availabilities.json' => :skill_availabilities_as_json,
        )
      end

      def relevant_skill?(skill)
        # do not export captain skills
        return false if skill['Scategory'] == SKILL_CAT_CAPTAIN
        # do not export enemy only skills
        return false if skill['Properties']&.include?('enemy_only')
        # do not export enemy only skills (part 2)
        # some skills from ennemies OCs (ex: "Bitter Winter") can appear
        # as long as the OC is not yet released as playable unit
        return false if skill[:owner_details]&.all? { |desc| desc['WikiName'].include?('ENEMY') }
        # do not export Kiran's weapons
        return false if skill[:owner_details]&.all? { |desc| desc['WikiName'].include?('Kiran') }
        # only export refines with effect
        return false unless [nil, '', 'skill1', 'skill2'].include?(skill['RefinePath'])

        true
      end

      def relevant_skills
        @relevant_skills ||= all_skills.select { |skill| relevant_skill?(skill) }
      end

      def relevant_skills_without_refine
        @relevant_skills_without_refine ||=
          relevant_skills
          .select { |skill| skill['RefinePath'].blank? }
      end

      private

      def rec_fill_skill_tier(skill, tier)
        skill[:tier] = tier
        return if skill[:upgrades_wikinames].nil?

        skill[:upgrades_wikinames].each do |skill_wikiname|
          rec_fill_skill_tier(all_skills_by_wikiname[skill_wikiname], tier + 1)
        end
      end

      def skills_as_json
        (relevant_skills + relevant_seals).map { |skill| skill_as_json(skill) } +
          all_duo_heroes.map { |hero| duo_skill_as_json(hero) }.compact +
          all_harmonized_heroes.map { |hero| harmonized_skill_as_json(hero) }.compact +
          all_emblem_heroes.map { |hero| emblem_skill_as_json(hero) }.compact
      end

      def duo_skill_as_json(hero)
        owner = all_units_by_pagename[hero['Page']]
        return (errors[:duo_skill_without_owner] << hero['Page']) if owner.nil?

        custom_skill_as_json(SKILL_CAT_DUO, owner)
      end

      def harmonized_skill_as_json(hero)
        owner = all_units_by_pagename[hero['Page']]
        return (errors[:harmonized_skill_without_owner] << hero['Page']) if owner.nil?

        custom_skill_as_json(SKILL_CAT_HARMONIZED, owner)
      end

      def emblem_skill_as_json(hero)
        owner = all_units_by_pagename[hero['Page']]
        return (errors[:emblem_skill_without_owner] << hero['Page']) if owner.nil?

        custom_skill_as_json(SKILL_CAT_EMBLEM, owner)
      end

      def custom_skill_as_json(category, owner)
        owner_page = sanitize_name(owner['Page'])
        {
          id: custom_id(category, owner),
          game8_id: owner[:game8_id],
          fandom_id: owner_page,
          name: owner_page,
          category:,

          is_prf: true,
          tier: 1,

          addition_date: owner['AdditionDate'],
          release_date:  owner['ReleaseDate'],
          version:       owner[:version],
        }
      end

      def custom_id(prefix, page)
        "#{prefix.upcase}_#{page['TagID']}"
      end

      def skill_as_json(skill)
        tier = skill[:tier]
        sp = skill['SP'].to_i unless skill['Scategory'] == SKILL_CAT_PASSIVE_X
        cd = skill['Cooldown'] == '-1' ? nil : skill['Cooldown'].to_i if skill['Scategory'] == SKILL_CAT_SPECIAL
        might = skill['Might'].presence&.to_i
        range = skill['UseRange'].presence&.to_i

        constants[:skills_max_tier] = tier if tier && constants[:skills_max_tier] < tier
        constants[:skills_max_sp] = sp if sp && constants[:skills_max_sp] < sp
        constants[:skills_max_cd] = cd if cd && constants[:skills_max_cd] < cd
        constants[:skills_max_might] = might if might && constants[:skills_max_might] < might
        constants[:skills_max_range] = range if range && constants[:skills_max_range] < range

        first_owner_detail =
          skill[:owner_details]
          &.reject { |us| us['additionDate'].nil? }
          &.min_by { |us| us['additionDate'] }
        if first_owner_detail
          unit = all_units_by_wikiname[first_owner_detail['WikiName']]
          if unit.nil?
            errors[:owner_not_found] << first_owner_detail['WikiName']
          else
            first_owner = unit
          end
        end

        name = sanitize_name(skill['Name'])
        if name == 'Falchion'
          suffix = skill['WikiName'].match(/\AFalchion ([^ ]+)/)[1]
          name = "#{name} (#{suffix})"
        end

        errors[:missing_tier_on_skill] << name if tier.nil?

        # MONKEY PATCH: fandom "CanUseWeapon" are blank when they should not...
        weapons_restrictions = sanitize_weapon_restriction(skill)
        if weapons_restrictions == self.class::INVALID_WEAPONS_RESTRICTIONS && s3
          weapons_restrictions =
            if skill['Scategory'] == self.class::SKILL_CAT_SACRED_SEAL
              (
                s3.all_skills_by_id[skill['TagID']] ||
                s3.all_skills_by_id[skill['TagID'].gsub(/\AS/, '')]
              )&.dig('restrictions', 'weapons')
            else
              s3.all_skills_by_id[skill['TagID']]&.dig('restrictions', 'weapons')
            end
        end

        is_prf = skill['Exclusive'] == '1'

        errors[:missing_refine_image] << name if skill[:base_id].present? && skill[:image_url].blank?

        has_name_of_unit = skill['WikiName'].include?('weapon')
        fandom_id = sanitize_name(skill['GroupName'])
        fandom_id = "#{name} (weapon)" if has_name_of_unit

        res = {
          id: skill['TagID'],
          base_id: skill[:base_id],
          game8_id: skill[:game8_id],
          fandom_id:,

          name:,
          category: skill['Scategory'],
          weapon_type: sanitize_weapon_type(skill),

          image_url: skill[:image_url],

          is_prf: true_or_nil(is_prf),
          is_arcane: true_or_nil(skill['Properties']&.include?('arcane')),
          sp:,
          tier:,
          range:,
          might:,

          has_refine: true_or_nil(skill[:refine_ids].present?),
          refines_max_sp: skill[:refine_ids]&.map { |id| all_skills_by_tag_id[id]['SP'].to_i }&.max,
          refine_kind: skill['RefinePath'].presence,

          cd:,
          eff: skill['WeaponEffectiveness'].presence&.split(','),

          restrictions: (
            if is_prf
              nil
            else
              {
                moves: sanitize_move_restriction(skill),
                weapons: weapons_restrictions,
              }
            end
          ),

          addition_date: first_owner&.dig('AdditionDate'),
          release_date:  first_owner&.dig('ReleaseDate'),
          version:       first_owner&.dig(:version),
        }

        if skill[:upgrades_wikinames]
          res[:upgrade_ids] = skill[:upgrades_wikinames].map do |name|
            upgrade =
              if skill['Scategory'] == self.class::SKILL_CAT_SACRED_SEAL
                all_seals_by_wikiname[name]
              else
                all_skills_by_wikiname[name]
              end
            next (errors[:skills_upgrades_without_skill] << [skill['WikiName'], name]) if upgrade.nil?

            upgrade['TagID']
          end.compact
        end
        if skill[:downgrades_wikinames]
          res[:downgrade_ids] = skill[:downgrades_wikinames].map do |name|
            downgrade =
              if skill['Scategory'] == self.class::SKILL_CAT_SACRED_SEAL
                all_seals_by_wikiname[name]
              else
                all_skills_by_wikiname[name]
              end
            next (errors[:skills_downgrades_without_skill] << [skill['WikiName'], name]) if downgrade.nil?

            downgrade['TagID']
          end.compact
        end

        res.compact
      end

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
        (relevant_skills + relevant_seals).map { |skill| skill_description_as_json(skill) }.compact +
          all_duo_heroes.map { |hero| duo_skill_desc_as_json(hero) }.compact +
          all_harmonized_heroes.map { |hero| harmonized_skill_desc_as_json(hero) }.compact +
          all_emblem_heroes.map { |hero| emblem_skill_desc_as_json(hero) }.compact
      end

      def skill_description_as_json(skill)
        full = sanitize_description(skill['Description'])
        return if full.nil?

        parts = full.split('<br><br>【')
        base = parts[0].presence
        base_keywords = parts[1..].map { |l| "【#{l}" }.presence

        if (upgrade = all_weapon_upgrades_by_wikiname[skill['WikiName']])
          base_desc = sanitize_description(upgrade['BaseDesc'])
          base_parts = base_desc.split('<br><br>【')
          base = base_parts[0].presence
          base_keywords = base_parts[1..].map { |l| "【#{l}" }.presence

          upgrade_d = sanitize_description(upgrade['AddedDesc'])
          upgrade_parts = upgrade_d.split('<br><br>【')
          upgrade_desc = upgrade_parts[0].presence
          upgrade_desc_keywords = upgrade_parts[1..].map { |l| "【#{l}" }.presence
        end

        constants[:keywords] += (base_keywords || []) + (upgrade_desc_keywords || [])

        {
          id: skill['TagID'],
          full:,
          base:,
          base_keywords:,
          upgrade: upgrade_desc,
          upgrade_keywords: upgrade_desc_keywords,
        }.compact
      end

      def duo_skill_desc_as_json(hero)
        owner = all_units_by_pagename[hero['Page']]
        return (errors[:duo_skill_without_owner_bis] << hero['Page']) if owner.nil?

        custom_skill_desc_as_json(
          custom_id(SKILL_CAT_DUO, owner),
          hero['DuoSkill'],
        )
      end

      def harmonized_skill_desc_as_json(hero)
        owner = all_units_by_pagename[hero['Page']]
        return (errors[:harmonized_skill_without_owner_bis] << hero['Page']) if owner.nil?

        custom_skill_desc_as_json(
          custom_id(SKILL_CAT_HARMONIZED, owner),
          hero['HarmonizedSkill'],
        )
      end

      def emblem_skill_desc_as_json(hero)
        owner = all_units_by_pagename[hero['Page']]
        return (errors[:emblem_skill_without_owner_bis] << hero['Page']) if owner.nil?

        custom_skill_desc_as_json(
          custom_id(SKILL_CAT_EMBLEM, owner),
          hero['Effect'],
        )
      end

      def custom_skill_desc_as_json(id, desc)
        full = sanitize_description(desc)
        parts = full.split('<br><br>【')
        base = parts[0].presence
        base_keywords = parts[1..].map { |l| "【#{l}" }.presence

        constants[:keywords] += base_keywords || []

        {
          id:,
          full:,
          base:,
          base_keywords:,
        }.compact
      end

      def sanitize_description(desc)
        return if desc.blank?

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
        relevant_skills.map { |skill| skill_availability_as_json(skill) } +
          all_duo_heroes.map { |hero| duo_skill_avail_as_json(hero) }.compact +
          all_harmonized_heroes.map { |hero| harmonized_skill_avail_as_json(hero) }.compact +
          all_emblem_heroes.map { |hero| emblem_skill_avail_as_json(hero) }.compact
      end

      def duo_skill_avail_as_json(hero)
        owner = all_units_by_pagename[hero['Page']]
        return (errors[:duo_skill_without_owner_ter] << hero['Page']) if owner.nil?

        custom_skill_avail_as_json(
          custom_id(SKILL_CAT_DUO, owner),
          owner,
        )
      end

      def harmonized_skill_avail_as_json(hero)
        owner = all_units_by_pagename[hero['Page']]
        return (errors[:harmonized_skill_without_owner_ter] << hero['Page']) if owner.nil?

        custom_skill_avail_as_json(
          custom_id(SKILL_CAT_HARMONIZED, owner),
          owner,
        )
      end

      def emblem_skill_avail_as_json(hero)
        owner = all_units_by_pagename[hero['Page']]
        return (errors[:emblem_skill_without_owner_ter] << hero['Page']) if owner.nil?

        custom_skill_avail_as_json(
          custom_id(SKILL_CAT_EMBLEM, owner),
          owner,
        )
      end

      def custom_skill_avail_as_json(id, owner)
        {
          id:,
          owner_ids: [owner['TagID']],
          is_in: obfuscate_keys(owner[:is_in]),
          self.class::OBFUSCATED_KEYS[:owner_lowest_rarity_when_obtained] =>
            obfuscate_keys(owner[:lowest_rarity].compact).presence,
          divine_codes: owner[:divine_codes].compact.presence,
        }.compact
      end

      def skill_availability_as_json(skill)
        owner_ids = []
        skill[:owner_details]&.each do |u|
          unit = all_units_by_wikiname[u['WikiName']]
          next (errors[:owner_not_found_bis] << u['WikiName']) if unit.nil?
          next unless relevant_unit?(unit)

          owner_ids << unit['TagID']
        end

        {
          id: skill['TagID'],

          owner_ids:,
          required_slots: skill[:prefodder]&.transform_values { |n| [1, n].max },
          is_in: obfuscate_keys(skill[:is_in]),
          self.class::OBFUSCATED_KEYS[:owner_lowest_rarity_when_obtained] =>
            obfuscate_keys(skill[:owner_lowest_rarity_when_obtained].compact).presence,
          self.class::OBFUSCATED_KEYS[:owner_lowest_rarity_for_inheritance] =>
            obfuscate_keys(skill[:owner_lowest_rarity_for_inheritance].compact).presence,
          divine_codes: skill[:divine_codes].compact.presence,
        }.compact
      end
    end
  end
end
