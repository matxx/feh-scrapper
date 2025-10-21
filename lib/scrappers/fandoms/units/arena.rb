# frozen_string_literal: true

module Scrappers
  module Fandoms
    module Units
      module Arena
        RARITY_1 = 1
        RARITY_2 = 2
        RARITY_3 = 3
        RARITY_4 = 4
        RARITY_5 = 5
        ARENA_SCORES_CONSTANTS = {
          RARITY_1 => {
            base_value: 47,
            level_factor: 68 / 39.0,
          },
          RARITY_2 => {
            base_value: 49,
            level_factor: 73 / 39.0,
          },
          RARITY_3 => {
            base_value: 51,
            level_factor: 79 / 39.0,
          },
          RARITY_4 => {
            base_value: 53,
            level_factor: 84 / 39.0,
          },
          RARITY_5 => {
            base_value: 55,
            level_factor: 7 / 3.0,
          },
        }.freeze

        # formula :
        # https://imgur.com/NycQzxt
        # other resources :
        # https://www.arcticsilverfox.com/score_calc/
        # https://feheroes.fandom.com/wiki/Fire_Emblem_Heroes_Wiki:Arena_score_tier_list
        # https://www.reddit.com/r/FireEmblemHeroes/comments/19atxtw/what_is_the_formula_for_calculating_arena_score/
        # https://www.reddit.com/r/OrderOfHeroes/comments/7ihbqv/the_most_accurate_arena_score_calculator_to_date/
        # https://docs.google.com/spreadsheets/d/1XF8AtQPzAIhyyW_fHHsbBd-Z2jWZM2rBwSkhWy8YeWk/edit?gid=1351020164#gid=1351020164
        def fill_units_with_arena_scores
          rarity_base_value   = ARENA_SCORES_CONSTANTS[RARITY_5][:base_value]
          rarity_level_factor = ARENA_SCORES_CONSTANTS[RARITY_5][:level_factor]
          level = 40
          team_base_score = 150

          all_units.each do |unit|
            total_skill_sp = unit[:skills_max_sp]
            if total_skill_sp.nil?
              errors[:units_without_skills2] << unit['WikiName'] unless unit['Properties']&.include?('enemy')
              next
            end

            merges_count = unit[:properties].include?('story') ? 0 : 10
            unit[:visible_bst] = unit[:duel_score] || unit[:bst]
            unit[:visible_bst] += (unit[:has_superboon] ? 4 : 3) if merges_count.positive?
            # adjust for "Duel" A skills
            unit[:visible_bst] = 180 if unit[:visible_bst] < 180 && unit['MoveType'] != self.class::MOVE_A

            total_bst = unit[:visible_bst]
            max_score =
              rarity_base_value +
              (rarity_level_factor * level).floor +
              (merges_count * 2) +
              (total_skill_sp / 100).floor +
              (total_bst / 5).floor

            logger.debug "-- #{unit['WikiName']}"
            logger.debug "rarity_base_value: #{rarity_base_value}"
            logger.debug "rarity_level_factor: #{rarity_level_factor}"
            logger.debug "level: #{level}"
            logger.debug "merges_count : #{merges_count}"
            logger.debug "total_skill_sp: #{total_skill_sp}"
            logger.debug "total_bst: #{total_bst}"

            logger.debug "rarity part : #{rarity_base_value}"
            logger.debug "level part : #{(rarity_level_factor * level).floor}"
            logger.debug "merges part : #{merges_count * 2}"
            logger.debug "skills part : #{(total_skill_sp / 100).floor}"
            logger.debug "bst part : #{(total_bst / 5).floor}"

            logger.debug "max_score : #{(team_base_score + max_score) * 2}"

            unit[:max_score] = (team_base_score + max_score) * 2
          end
        end
      end
    end
  end
end
