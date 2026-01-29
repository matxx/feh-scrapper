# frozen_string_literal: true

module Scrappers
  module Fandoms
    module WeaponUpgrades
      attr_reader(
        :all_weapon_upgrades,
        :all_weapon_upgrades_by_wikiname,
      )

      def reset_all_weapon_upgrades!
        @all_weapon_upgrades = nil
        @all_weapon_upgrades_by_wikiname = nil
      end

      # https://feheroes.fandom.com/wiki/Special:CargoTables/WeaponUpgrades
      def scrap_weapon_upgrades
        return if all_weapon_upgrades

        fields = [
          '_pageName=Page',
          'BaseWeapon',
          'UpgradesInto',
          # 'CostMedals',
          # 'CostStones',
          # 'CostDews',
          # 'StatModifiers',
          'BaseDesc',
          'AddedDesc',
        ]

        @all_weapon_upgrades = retrieve_all_pages('WeaponUpgrades', fields)
        @all_weapon_upgrades_by_wikiname =
          all_weapon_upgrades
          .index_by { |x| x['UpgradesInto'] }

        weapon_upgrades_with_same_wikiname =
          all_weapon_upgrades
          .group_by { |x| x['UpgradesInto'] }
          .select { |_, v| v.size > 1 }
        return if weapon_upgrades_with_same_wikiname.empty?

        errors[:weapon_upgrades_with_same_wikiname] = weapon_upgrades_with_same_wikiname.keys
      end
    end
  end
end
