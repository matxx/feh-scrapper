# frozen_string_literal: true

module Scrappers
  module Fandoms
    module UnitsFodder
      MODE_HEROIC_GRAILS = 'hg'
      MODE_DIVINE_CODES = 'dc'
      MODE_GENERIC_POOL_4 = 'g4'
      MODE_GENERIC_POOL_45 = 'gsr'
      MODE_GENERIC_POOL_5 = 'g5'
      MODE_SPECIAL_POOL_4 = 'sh4'
      MODE_SPECIAL_POOL_45 = 'shsr'
      MODE_SPECIAL_POOL_5 = 'sh5'
      MODES_IN_ORDER = [
        MODE_GENERIC_POOL_4,
        MODE_HEROIC_GRAILS,
        MODE_DIVINE_CODES,
        MODE_SPECIAL_POOL_4,
        MODE_GENERIC_POOL_45,
        MODE_SPECIAL_POOL_45,
        MODE_GENERIC_POOL_5,
        MODE_SPECIAL_POOL_5,
      ].freeze

      def fill_skills_with_prefodder
        skills_min_tier = all_skills.select { |skill| skill[:downgrades_wikinames].nil? }
        logger.debug "- fill_skills_with_prefodder : #{skills_min_tier.size}"
        rec_compute_skills_fodder(skills_min_tier)
      end

      def rec_compute_skills_fodder(skills, tier = 0)
        return if skills.empty?

        logger.debug "-- rec_compute_skills_fodder : #{tier}"

        next_tier_skills = Set.new
        skills.each do |skill|
          logger.debug "--> skill : #{skill['Name']}"
          skill[:prefodder_one_mode] = {}

          if skill[:upgrades_wikinames]
            next_tier_skills += skill[:upgrades_wikinames].map do |name|
              upgrade = all_skills_by_wikiname[name]
              next (errors[:units_fodder_without_upgrade] << [skill['WikiName'], name]) if upgrade.nil?

              upgrade
            end.compact
          end
          if skill[:downgrades_wikinames]
            downgrades = skill[:downgrades_wikinames].map do |name|
              downgrade = all_skills_by_wikiname[name]
              next (errors[:units_fodder_without_downgrade] << [skill['WikiName'], name]) if downgrade.nil?

              downgrade
            end.compact
          end

          [
            [MODE_HEROIC_GRAILS, :heroic_grails],
            [MODE_DIVINE_CODES, :normal_divine_codes],
          ].each do |key_prefodder, key_is_in|
            skill[:prefodder_one_mode][key_prefodder] =
              if skill[:is_in][key_is_in]
                0
              else
                downgrades_prefodder(skill, downgrades, key_prefodder) + 1
              end
          end

          skill[:prefodder_one_mode][MODE_GENERIC_POOL_4] =
            downgrades_prefodder(skill, downgrades, MODE_GENERIC_POOL_4) + 1
          skill[:prefodder_one_mode][MODE_GENERIC_POOL_45] =
            downgrades_prefodder(skill, downgrades, MODE_GENERIC_POOL_45) + 1
          skill[:prefodder_one_mode][MODE_GENERIC_POOL_5] =
            downgrades_prefodder(skill, downgrades, MODE_GENERIC_POOL_5) + 1
          if skill[:is_in][:generic_summon_pool]
            rarity = skill[:owner_lowest_rarity_when_obtained][:generic_summon_pool]
            case rarity
            when 1, 2, 3, 4
              skill[:prefodder_one_mode][MODE_GENERIC_POOL_4] = 0
            when 4.5
              skill[:prefodder_one_mode][MODE_GENERIC_POOL_45] = 0
            when 5
              skill[:prefodder_one_mode][MODE_GENERIC_POOL_5] = 0
            else
              errors[:skill_fodder_with_generic_weird_rarity] << [skill['WikiName'], :rarity]
            end
          end

          skill[:prefodder_one_mode][MODE_SPECIAL_POOL_4] =
            downgrades_prefodder(skill, downgrades, MODE_SPECIAL_POOL_4) + 1
          skill[:prefodder_one_mode][MODE_SPECIAL_POOL_45] =
            downgrades_prefodder(skill, downgrades, MODE_SPECIAL_POOL_45) + 1
          skill[:prefodder_one_mode][MODE_SPECIAL_POOL_5] =
            downgrades_prefodder(skill, downgrades, MODE_SPECIAL_POOL_5) + 1
          if skill[:is_in][:special_summon_pool]
            rarity = skill[:owner_lowest_rarity_when_obtained][:special_summon_pool]
            case rarity
            when 4
              skill[:prefodder_one_mode][MODE_SPECIAL_POOL_4] = 0
            when 4.5
              skill[:prefodder_one_mode][MODE_SPECIAL_POOL_45] = 0
            when 5
              skill[:prefodder_one_mode][MODE_SPECIAL_POOL_5] = 0
            else
              errors[:skill_fodder_with_special_weird_rarity] << [skill['WikiName'], rarity]
            end
          end

          skill[:prefodder] = {}
          (0...MODES_IN_ORDER.length).to_a.each do |index|
            mode = MODES_IN_ORDER[index]
            # skill[:prefodder][mode] = MODES_IN_ORDER[0..index].map { |m| skill[:prefodder_one_mode][m] }.compact.min
            skill[:prefodder][mode] = skill[:prefodder_one_mode][mode]
          end

          nil # rubocop:disable Lint/Void
        end

        rec_compute_skills_fodder(next_tier_skills, tier + 1)
      end

      def downgrades_prefodder(skill, downgrades, mode)
        return 0 if downgrades.nil?

        downgrades.map do |downgrade|
          hash = downgrade[:prefodder_one_mode]
          if hash.nil?
            errors[:downgrade_without_prefodder] << [skill['WikiName'], downgrade]
            next 25
          end

          if downgrade[:prefodder_one_mode][mode].nil?
            errors[:downgrade_without_prefodder_mode] << [skill['WikiName'], downgrade, mode]
            next 30
          end

          downgrade[:prefodder_one_mode][mode]
        end.min
      end
    end
  end
end
