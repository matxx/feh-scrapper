# frozen_string_literal: true

module Scrappers
  module Fandoms
    module SkillsWeapons
      WEAPON_R_SW = 'Red Sword'
      WEAPON_R_BO = 'Red Bow'
      WEAPON_R_DA = 'Red Dagger'
      WEAPON_R_TO = 'Red Tome'
      WEAPON_R_BR = 'Red Breath'
      WEAPON_R_BE = 'Red Beast'

      WEAPON_B_LA = 'Blue Lance'
      WEAPON_B_BO = 'Blue Bow'
      WEAPON_B_DA = 'Blue Dagger'
      WEAPON_B_TO = 'Blue Tome'
      WEAPON_B_BR = 'Blue Breath'
      WEAPON_B_BE = 'Blue Beast'

      WEAPON_G_AX = 'Green Axe'
      WEAPON_G_BO = 'Green Bow'
      WEAPON_G_DA = 'Green Dagger'
      WEAPON_G_TO = 'Green Tome'
      WEAPON_G_BR = 'Green Breath'
      WEAPON_G_BE = 'Green Beast'

      WEAPON_C_ST = 'Colorless Staff'
      WEAPON_C_BO = 'Colorless Bow'
      WEAPON_C_DA = 'Colorless Dagger'
      WEAPON_C_TO = 'Colorless Tome'
      WEAPON_C_BR = 'Colorless Breath'
      WEAPON_C_BE = 'Colorless Beast'

      ALL_WEAPONS = [
        WEAPON_R_SW,
        WEAPON_R_BO,
        WEAPON_R_DA,
        WEAPON_R_TO,
        WEAPON_R_BR,
        WEAPON_R_BE,

        WEAPON_B_LA,
        WEAPON_B_BO,
        WEAPON_B_DA,
        WEAPON_B_TO,
        WEAPON_B_BR,
        WEAPON_B_BE,

        WEAPON_G_AX,
        WEAPON_G_BO,
        WEAPON_G_DA,
        WEAPON_G_TO,
        WEAPON_G_BR,
        WEAPON_G_BE,

        WEAPON_C_ST,
        WEAPON_C_BO,
        WEAPON_C_DA,
        WEAPON_C_TO,
        WEAPON_C_BR,
        WEAPON_C_BE,
      ].freeze
      WEAPONS_COUNT = ALL_WEAPONS.length

      # horizontal aggregations

      WEAPON_A_MELEE = 'All Melee'

      # WEAPON_A_SW = 'All Sword'
      # WEAPON_A_LA = 'All Lance'
      # WEAPON_A_AX = 'All Axe'
      # WEAPON_A_ST = 'All Staff'

      WEAPON_A_BO = 'All Bow'
      WEAPON_A_DA = 'All Dagger'
      WEAPON_A_TO = 'All Tome'
      WEAPON_A_BR = 'All Breath'
      WEAPON_A_BE = 'All Beast'

      ALL_MELEE = [
        WEAPON_R_SW,
        WEAPON_B_LA,
        WEAPON_G_AX,
      ].freeze

      ALL_BOWS = [
        WEAPON_R_BO,
        WEAPON_B_BO,
        WEAPON_G_BO,
        WEAPON_C_BO,
      ].freeze
      ALL_DAGGERS = [
        WEAPON_R_DA,
        WEAPON_B_DA,
        WEAPON_G_DA,
        WEAPON_C_DA,
      ].freeze
      ALL_TOMES = [
        WEAPON_R_TO,
        WEAPON_B_TO,
        WEAPON_G_TO,
        WEAPON_C_TO,
      ].freeze
      ALL_BREATHES = [
        WEAPON_R_BR,
        WEAPON_B_BR,
        WEAPON_G_BR,
        WEAPON_C_BR,
      ].freeze
      ALL_BEASTS = [
        WEAPON_R_BE,
        WEAPON_B_BE,
        WEAPON_G_BE,
        WEAPON_C_BE,
      ].freeze

      # vertical aggregations

      WEAPON_R = 'Red'
      WEAPON_B = 'Blue'
      WEAPON_G = 'Green'
      WEAPON_C = 'Colorless'

      ALL_BLUES = [
        WEAPON_R_SW,
        WEAPON_R_BO,
        WEAPON_R_DA,
        WEAPON_R_TO,
        WEAPON_R_BR,
        WEAPON_R_BE,
      ].freeze

      ALL_REDS = [
        WEAPON_B_LA,
        WEAPON_B_BO,
        WEAPON_B_DA,
        WEAPON_B_TO,
        WEAPON_B_BR,
        WEAPON_B_BE,
      ].freeze

      ALL_GREENS = [
        WEAPON_G_AX,
        WEAPON_G_BO,
        WEAPON_G_DA,
        WEAPON_G_TO,
        WEAPON_G_BR,
        WEAPON_G_BE,
      ].freeze

      ALL_COLORLESS = [
        WEAPON_C_ST,
        WEAPON_C_BO,
        WEAPON_C_DA,
        WEAPON_C_TO,
        WEAPON_C_BR,
        WEAPON_C_BE,
      ].freeze

      # TODO: unit tests
      def sanitize_weapon_restriction(skill, prefix = :skill)
        tmp_can_use = skill['CanUseWeapon'].split(/,[[:space:]]*/)
        tmp_can_use.uniq!

        errors[:"#{prefix}_with_unknown_weapon_restrictions"] << skill if (tmp_can_use - ALL_WEAPONS).any?

        return { none: true } if tmp_can_use.length == WEAPONS_COUNT
        return { can_not_use: [WEAPON_C_ST] } if (ALL_WEAPONS - tmp_can_use) == [WEAPON_C_ST]

        {
          ALL_BLUES => WEAPON_R,
          ALL_REDS => WEAPON_B,
          ALL_GREENS => WEAPON_G,
          ALL_COLORLESS => WEAPON_C,
        }.each do |array, elem|
          return { can_use: [elem] } if tmp_can_use.length == array.length

          if !array.intersect?(tmp_can_use) && (tmp_can_use + array).length == WEAPONS_COUNT
            return { can_not_use: [elem] }
          end
        end

        can_use = []
        can_not_use = []

        if (ALL_MELEE - tmp_can_use).empty?
          can_use << WEAPON_A_MELEE
        elsif !ALL_MELEE.intersect?(tmp_can_use)
          can_not_use << WEAPON_A_MELEE
        else
          can_use << WEAPON_R_SW if tmp_can_use.include?(WEAPON_R_SW)
          can_use << WEAPON_B_LA if tmp_can_use.include?(WEAPON_B_LA)
          can_use << WEAPON_G_AX if tmp_can_use.include?(WEAPON_G_AX)
        end

        if tmp_can_use.include?(WEAPON_C_ST)
          can_use << WEAPON_C_ST
        else
          can_not_use << WEAPON_C_ST
        end

        if (ALL_TOMES - tmp_can_use).empty?
          can_use << WEAPON_A_TO
        elsif !ALL_TOMES.intersect?(tmp_can_use)
          can_not_use << WEAPON_A_TO
        else
          can_use << WEAPON_R_TO if tmp_can_use.include?(WEAPON_R_TO)
          can_use << WEAPON_B_TO if tmp_can_use.include?(WEAPON_B_TO)
          can_use << WEAPON_G_TO if tmp_can_use.include?(WEAPON_G_TO)
          can_use << WEAPON_C_TO if tmp_can_use.include?(WEAPON_C_TO)
        end

        {
          ALL_BOWS => WEAPON_A_BO,
          ALL_DAGGERS => WEAPON_A_DA,
          ALL_BREATHES => WEAPON_A_BR,
          ALL_BEASTS => WEAPON_A_BE,
        }.each do |array, elem|
          if (array - tmp_can_use).empty?
            can_use << elem
          elsif !array.intersect?(tmp_can_use)
            can_not_use << elem
          elsif !skill['Name'].include?('Cancel Affinity')
            errors[:"#{prefix}_with_weird_weapon_restrictions"] << [skill, array, elem]
          end
        end

        if can_use.length <= can_not_use.length
          { can_use: }
        else
          { can_not_use: }
        end
      end

      def sanitize_weapon_type(skill)
        return unless skill['Scategory'] == self.class::WEAPON

        can_use = skill['CanUseWeapon'].split(/,[[:space:]]*/)
        can_use.uniq!

        return WEAPON_A_BO if (ALL_BOWS - can_use).empty?
        return WEAPON_A_DA if (ALL_DAGGERS - can_use).empty?
        return WEAPON_A_TO if (ALL_TOMES - can_use).empty?
        return WEAPON_A_BR if (ALL_BREATHES - can_use).empty?
        return WEAPON_A_BE if (ALL_BEASTS - can_use).empty?

        return can_use[0] if can_use.size == 1

        errors[:not_sanitizable_weapon_type] << skill
      end
    end
  end
end
