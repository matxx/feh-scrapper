# frozen_string_literal: true

module Scrappers
  module Fandoms
    module SacredSealCosts
      attr_reader(
        :all_sacred_seal_costs,
        :all_seals,
      )

      def reset_all_sacred_seal_costs!
        @all_sacred_seal_costs = nil
        @all_seals = nil
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

        @all_seals = seals_from_skills
        @all_seals += seals_from_costs_table

        nil
      end

      def export_seals
        export_files(
          'seals.json' => :seals_as_json,
          'seals-descriptions.json' => :seals_descriptions_as_json,
        )
      end

      private

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

      def seals_as_json
        all_seals.map { |seal| seal_as_json(seal) }
      end

      def seal_as_json(seal)
        # MONKEY PATCH: fandom "CanUseWeapon" are blank when they should not...
        weapons_restrictions = sanitize_weapon_restriction(seal, :seal)
        if weapons_restrictions == self.class::INVALID_WEAPONS_RESTRICTIONS && s3
          weapons_restrictions = s3.all_seals_by_id[seal['TagID']]&.dig('restrictions', 'weapons')
        end

        {
          id: seal['TagID'],
          game8_id: seal[:game8_id],
          name: seal['Name'],
          group_name: seal['GroupName'],
          image_url: seal[:image_url],
          sp: seal['SP'].to_i,
          # tier: seal[:tier], # populate needed

          restrictions: {
            moves: sanitize_move_restriction(seal, :seal),
            weapons: weapons_restrictions,
          },
        }
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
