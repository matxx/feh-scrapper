# frozen_string_literal: true

module Scrappers
  module Fandoms
    module Seals
      attr_reader(
        :all_sacred_seal_costs,
        :all_seals,
        :all_seals_by_wikiname,
        :all_seals_grouped_by_name,
        :all_seals_by_name,
      )

      def reset_all_sacred_seal_costs!
        @all_sacred_seal_costs = nil
        @all_seals = nil
        @all_seals_by_wikiname = nil
        @all_seals_grouped_by_name = nil
        @all_seals_by_name = nil
      end

      def reset_cached_seals!
        @relevant_seals = nil
      end

      # https://feheroes.fandom.com/wiki/Special:CargoTables/SacredSealCosts
      def scrap_sacred_seal_costs
        return if all_sacred_seal_costs

        fields = [
          'Skill',
          # 'BadgeColor',
          # 'BadgeCost',
          # 'GreatBadgeCost',
          # 'SacredCoinCost',
        ]
        @all_sacred_seal_costs = retrieve_all_pages('SacredSealCosts', fields)

        nil
      end

      def compute_all_seals
        return if all_seals

        @all_seals = seals_from_skills # seals not available as skills
        @all_seals += seals_from_costs_table # seals available as skills

        @all_seals.each do |seal|
          # make sure that seals have a different ID than skills
          seal['TagID'] = "S#{seal['TagID']}"
        end

        @all_seals_by_wikiname = all_seals.index_by { |x| x['WikiName'] }
        @all_seals_grouped_by_name = all_seals.group_by { |x| x['Name'] }
        @all_seals_by_name =
          all_seals
          .reject { |x| x['RefinePath'].present? }
          .index_by { |x| x['Name'] }

        seals_with_same_wikiname = all_seals.group_by { |x| x['WikiName'] }.select { |_, v| v.size > 1 }
        errors[:seals_with_same_wikiname] = seals_with_same_wikiname.keys if seals_with_same_wikiname.any?

        nil
      end

      def export_seals
        export_files(
          'seals.json' => :seals_as_json,
          'seals-descriptions.json' => :seals_descriptions_as_json,
        )
      end

      def fill_seals_with_genealogy
        all_seals.each do |seal|
          next if seal['Required'].blank?

          seal[:downgrades_wikinames] = seal['Required'].split(';')
          seal[:downgrades_wikinames].each do |downgrade_wikiname|
            downgrade = all_seals_by_wikiname[downgrade_wikiname]
            downgrade[:upgrades_wikinames] ||= Set.new
            downgrade[:upgrades_wikinames].add(seal['WikiName'])
          end
        end

        # rubocop:disable Style/CombinableLoops
        # this loop needs all the downgrades/upgrades to be filled,
        # so it can not be combined with previous loop
        all_seals.each do |seal|
          next if seal['Required'].present?

          rec_fill_seal_tier(seal, 1)
        end
        # rubocop:enable Style/CombinableLoops

        nil
      end

      private

      def rec_fill_seal_tier(seal, tier)
        seal[:tier] = tier
        return if seal[:upgrades_wikinames].nil?

        seal[:upgrades_wikinames].each do |seal_wikiname|
          upgrade = all_seals_by_wikiname[seal_wikiname]
          next (errors[:seals_upgrades_not_found] << [seal['Name'], tier, seal_wikiname]) if upgrade.nil?

          rec_fill_seal_tier(upgrade, tier + 1)
        end
      end

      def seals_from_costs_table
        all_sacred_seal_costs.map do |x|
          name = x['Skill']
          next if seals_from_skills_by_name[name]

          skill = all_skills_by_name[name]
          if skill.nil?
            errors[:sacred_seal_not_found] << name
            next
          end

          skill.except(:game8_id).merge('Scategory' => self.class::SACRED_SEAL)
        end.compact
      end

      def relevant_seal?(seal)
        # do not export enemy only seals
        return false if seal['Properties']&.include?('enemy_only')

        true
      end

      def relevant_seals
        @relevant_seals ||= all_seals.select { |seal| relevant_seal?(seal) }
      end

      def seals_as_json
        relevant_seals.map { |seal| seal_as_json(seal) }
      end

      def seal_as_json(seal)
        tier = seal[:tier]
        sp = seal['SP'].to_i

        # constants[:seals_max_tier] = tier if tier && constants[:seals_max_tier] < tier
        # constants[:seals_max_sp] = sp if constants[:seals_max_sp] < sp

        # MONKEY PATCH: fandom "CanUseWeapon" are blank when they should not...
        weapons_restrictions = sanitize_weapon_restriction(seal, :seal)
        if weapons_restrictions == self.class::INVALID_WEAPONS_RESTRICTIONS && s3
          weapons_restrictions =
            (
              s3.all_seals_by_id[seal['TagID']] ||
              s3.all_seals_by_id[seal['TagID'].gsub(/\AS/, '')]
            )&.dig('restrictions', 'weapons')
        end

        res = {
          id: seal['TagID'],
          game8_id: seal[:game8_id],
          name: seal['Name'],
          group_name: seal['GroupName'],
          image_url: seal[:image_url],
          sp:,
          tier:,

          restrictions: {
            moves: sanitize_move_restriction(seal, :seal),
            weapons: weapons_restrictions,
          },
        }

        if seal[:upgrades_wikinames]
          res[:upgrade_ids] = seal[:upgrades_wikinames].map do |name|
            upgrade = all_seals_by_wikiname[name]
            next (errors[:seals_upgrades_without_seal] << [seal['WikiName'], name]) if upgrade.nil?

            upgrade['TagID']
          end.compact
        end
        if seal[:downgrades_wikinames]
          res[:downgrade_ids] = seal[:downgrades_wikinames].map do |name|
            downgrade = all_seals_by_wikiname[name]
            next (errors[:seals_downgrades_without_seal] << [seal['WikiName'], name]) if downgrade.nil?

            downgrade['TagID']
          end.compact
        end

        res.compact
      end

      def seals_descriptions_as_json
        all_seals.map { |seal| seal_description_as_json(seal) }
      end

      def seal_description_as_json(seal)
        {
          id: seal['TagID'],
          description: sanitize_description(seal['Description']),
        }
      end
    end
  end
end
