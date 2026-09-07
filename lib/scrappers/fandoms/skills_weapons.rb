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

      ALL_REDS = [
        WEAPON_R_SW,
        WEAPON_R_BO,
        WEAPON_R_DA,
        WEAPON_R_TO,
        WEAPON_R_BR,
        WEAPON_R_BE,
      ].freeze

      ALL_BLUES = [
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

      # Paired with their one-word/one-phrase label, in the fixed order
      # `summarize_weapons` checks and lists them in.
      COLOR_GROUPS = [ALL_REDS, ALL_BLUES, ALL_GREENS, ALL_COLORLESS].freeze
      COLOR_LABELS = [WEAPON_R, WEAPON_B, WEAPON_G, WEAPON_C].freeze

      FAMILY_GROUPS = [ALL_BOWS, ALL_DAGGERS, ALL_TOMES, ALL_BREATHES, ALL_BEASTS].freeze
      FAMILY_LABELS = [WEAPON_A_BO, WEAPON_A_DA, WEAPON_A_TO, WEAPON_A_BR, WEAPON_A_BE].freeze

      # Same as FAMILY_GROUPS/FAMILY_LABELS, minus Tome: a tome user's color is fixed
      # for good on obtention (no cross-color transfer), so CanUseWeapon listing only
      # one tome color is the norm, not a weird/inconsistent restriction worth flagging
      # (unlike an uneven color split for bows/daggers/breaths/beasts).
      WEIRD_RESTRICTION_GROUPS = [ALL_BOWS, ALL_DAGGERS, ALL_BREATHES, ALL_BEASTS].freeze
      WEIRD_RESTRICTION_LABELS = [WEAPON_A_BO, WEAPON_A_DA, WEAPON_A_BR, WEAPON_A_BE].freeze

      def sanitize_weapon_restriction(skill, prefix = :skill)
        tmp_can_use = skill['CanUseWeapon'].split(/,[[:space:]]*/)
        tmp_can_use.uniq!

        errors[:"#{prefix}_with_unknown_weapon_restrictions"] << skill['WikiName'] if (tmp_can_use - ALL_WEAPONS).any?

        return { none: true } if tmp_can_use.length == WEAPONS_COUNT

        flag_weird_weapon_restrictions(skill, tmp_can_use, prefix)

        can_use = summarize_weapons(tmp_can_use)
        can_not_use = summarize_weapons(ALL_WEAPONS - tmp_can_use)

        if can_use.length <= can_not_use.length
          { can_use: }
        else
          { can_not_use: }
        end
      end

      def sanitize_weapon_type(skill)
        return unless skill['Scategory'] == self.class::SKILL_CAT_WEAPON

        can_use = skill['CanUseWeapon'].split(/,[[:space:]]*/)
        can_use.uniq!

        return WEAPON_A_BO if (ALL_BOWS - can_use).empty?
        return WEAPON_A_DA if (ALL_DAGGERS - can_use).empty?
        return WEAPON_A_TO if (ALL_TOMES - can_use).empty?
        return WEAPON_A_BR if (ALL_BREATHES - can_use).empty?
        return WEAPON_A_BE if (ALL_BEASTS - can_use).empty?

        return can_use[0] if can_use.size == 1

        errors[:not_sanitizable_weapon_type] << skill['WikiName']
      end

      private

      # Logs a "weird restriction" warning when a skill uses some, but not all, of a
      # weapon family (bow/dagger/breath/beast) across colors, in a way that isn't
      # explained by a color being entirely excluded (see `weird_family?`). Cancel
      # Affinity skills are exempt outright: they're expected to single out one
      # color within a family on purpose, while every color stays otherwise usable
      # via the other families — a pattern `weird_family?` can't tell apart from a
      # genuinely inconsistent restriction. The raw CanUseWeapon is included last so
      # a weird-restrictions export is debuggable without going back to the source
      # data.
      def flag_weird_weapon_restrictions(skill, tmp_can_use, prefix)
        return if skill['GroupName'] == 'Cancel Affinity'

        WEIRD_RESTRICTION_GROUPS.each_with_index do |array, index|
          next unless weird_family?(array, tmp_can_use)

          errors[:"#{prefix}_with_weird_weapon_restrictions"] <<
            [skill['WikiName'], array, WEIRD_RESTRICTION_LABELS[index], skill['CanUseWeapon']]
        end
      end

      # True when `family` (e.g. ALL_BOWS, listed Red/Blue/Green/Colorless like
      # COLOR_GROUPS) is present for some, but not all, of the colors that have ANY
      # presence at all in `weapons`. Colors entirely absent from `weapons` are
      # ignored: a gap there is just a side effect of that whole color being
      # excluded (Feud, Duel, Triangle Adept, Axebreaker/Swordbreaker...), not a
      # genuinely inconsistent restriction.
      def weird_family?(family, weapons)
        relevant = COLOR_GROUPS.zip(family).select { |color_group, _member| color_group.intersect?(weapons) }
        return false if relevant.empty?

        relevant.map { |_color_group, member| weapons.include?(member) }.uniq.length > 1
      end

      # Describes `weapons` as the shortest meaningful list of labels: a full color
      # (e.g. "Red"), a full weapon-type family across colors (e.g. "All Bow"), "All
      # Melee" (the sword/lance/axe trio), and finally any leftover single weapons.
      # Colors are checked first, then Melee, then the other families — each against
      # the full `weapons` set, so overlapping groups (e.g. "Red" and "All Bow" both
      # covering Red Bow) can both legitimately apply. This is what lets a skill that
      # mixes a fully-excluded color with fully-excluded weapon families (e.g. "cannot
      # use Red, or any Bow, Dagger, or Tome") resolve to a short, meaningful list
      # instead of one entry per leftover weapon.
      def summarize_weapons(weapons)
        labels = []
        covered = []

        COLOR_GROUPS.each_with_index do |group, index|
          next unless (group - weapons).empty?

          labels << COLOR_LABELS[index]
          covered.concat(group)
        end

        if (ALL_MELEE - weapons).empty?
          labels << WEAPON_A_MELEE
          covered.concat(ALL_MELEE)
        end

        FAMILY_GROUPS.each_with_index do |group, index|
          next unless (group - weapons).empty?

          labels << FAMILY_LABELS[index]
          covered.concat(group)
        end

        labels + (ALL_WEAPONS & (weapons - covered))
      end
    end
  end
end
