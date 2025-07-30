# frozen_string_literal: true

require 'awesome_print'

require 'scrappers/base'
require 'scrappers/fandom'
require 'scrappers/game8'

module Scrappers
  class All < Base
    attr_reader(
      :now,
      :logger,
      :errors,
      :all_skills,
      :all_skills_by_id,
      :all_seals,
      :all_seals_by_id,
      :all_units,
      :all_units_by_id,
    )
    attr_accessor(
      :fandom,
      :game8,
    )

    def initialize(level: Logger::ERROR, game8: {})
      @now = Time.now
      @logger = Logger.new($stdout)
      logger.level = level

      @fandom = Scrappers::Fandom.new(level:)
      @game8  = Scrappers::Game8.new(level:, **game8)

      boot
      setup_s3

      super
    end

    def reset!
      boot
      fandom.reset!
      game8.reset!

      nil
    end

    def handle_everything
      game8.log_and_launch(:handle_everything)
      fandom.log_and_launch(:handle_everything)

      log_and_launch(:retrieve_game8_unit_ratings)
      log_and_launch(:retrieve_game8_skill_ratings)

      @all_units_by_id = all_units.index_by { |s| s[:id] }
      @all_skills_by_id = all_skills.index_by { |s| s[:id] }
      @all_seals_by_id = all_seals.index_by { |s| s[:id] }

      log_and_launch(:fill_fandom_units_with_game8_data)
      log_and_launch(:fill_fandom_skills_with_game8_data)
      log_and_launch(:fill_fandom_seals_with_game8_data)

      log_and_launch(:export_game8_unit_ratings)
      log_and_launch(:export_game8_skill_ratings)
      log_and_launch(:export_game8_seal_ratings)

      fandom.log_and_launch(:export_everything)

      log_and_launch(:export_errors)

      nil
    end

    # game8 => fandom
    CATEGORY_GAME8_TO_FANDOM = {
      'skills_weapon' => 'weapon',
      'skills_assist' => 'assist',
      'skills_special' => 'special',
      'skills_a' => 'passivea',
      'skills_b' => 'passiveb',
      'skills_c' => 'passivec',
      'skills_s' => 'sacredseal',
      'skills_x' => 'passivex',
    }.freeze

    # game8 => fandom
    SKILL_NAME_SUBSTITUTIONS = {
      'Believe in Love？' => 'Believe in Love?',
      'Dark Spikes T' => 'Dark Spikes Τ',
      'Distant Counter (D)' => 'Dist. Counter (D)',
      'Distant Counter (M)' => 'Dist. Counter (M)',
      'Firesweep Sword' => 'Firesweep S',
      'Firesweep Sword+' => 'Firesweep S+',
      'Firesweep Lance+' => 'Firesweep L+',
      'In the Fold+' => 'In The Fold+',
      'Light is Time' => 'Light Is Time',
      'Lucrative Bow' => 'Gainful Bow',
      'Lucrative Bow+' => 'Gainful Bow+',
      'Oðr of Creation' => 'Óðr of Creation',
      'Pulse Up：Blades' => 'Pulse Up: Blades',
      'Pulse Up：Ploy' => 'Pulse Up: Ploy',
      'Pulse On：Blades' => 'Pulse On: Blades',
      'Red Tome Valor 1' => 'R Tome Valor 1',
      'Red Tome Valor 2' => 'R Tome Valor 2',
      'Red Tome Valor 3' => 'R Tome Valor 3',
      'Time is Light' => 'Time Is Light',
      'Yearling (Armored)' => 'Yearling (Arm.)',
      'Full Light ＆ Dark' => 'Full Light &amp; Dark',
      'Blood ＆ Thunder' => 'Blood &amp; Thunder',
    }.freeze

    GAME8_SKILLS_TO_IGNORE = [
      # Kiran weapon
      'Dire Breidablik',
      # game8 has only one page for Falchion
      # but there are 3 versions of it
      'Falchion',
      # ennemy skills
      'Élivágar',
      'Hel Scythe',
      'Kvasir',
      'Valaskjálf',
    ].freeze

    def retrieve_game8_skill_ratings
      f_skills_by_cat = fandom.relevant_skills_without_refine.group_by { |s| s['Scategory'] }
      f_skill_by_cat_and_name = f_skills_by_cat.transform_values { |skills| skills.index_by { |s| s['Name'] } }
      f_seals_by_name = fandom.all_seals.index_by { |s| s['Name'] }

      game8.all_skills.each do |g_skill|
        next if GAME8_SKILLS_TO_IGNORE.include?(g_skill['game8_name'])

        skill_by_name =
          if g_skill['category'] == game8.class::SKILLS_S
            f_seals_by_name
          else
            f_skill_by_cat_and_name[CATEGORY_GAME8_TO_FANDOM[g_skill['category']]]
          end
        skill_name = g_skill['game8_name']
        skill_name = SKILL_NAME_SUBSTITUTIONS[skill_name] if SKILL_NAME_SUBSTITUTIONS.key?(skill_name)

        # need to match those by wikiname because of same name
        case skill_name
        when 'Missiletainn (sword)'
          next store_skill(skill_id_bis('Missiletainn sword'), g_skill)
        when 'Missiletainn (tome)'
          next store_skill(skill_id_bis('Missiletainn tome'), g_skill)
        end

        f_skill = skill_by_name[skill_name]
        next store_skill(f_skill['TagID'], g_skill) if f_skill

        # logger.debug("skill not found : #{skill_name}")
        # logger.debug(g_skill.inspect)
        # logger.debug(skill_by_name.keys.inspect)

        true_skill_name, distance = skill_by_name.map { |name, _| [name, lev(name, skill_name)] }.min_by(&:last)
        if distance < 5
          errors[:skill_approximations] << { cat: g_skill['category'], game8: skill_name, fandom: true_skill_name }
        else
          errors[:fandom_skill_not_found] << { cat: g_skill['category'], game8: skill_name }
          next
        end

        store_skill(skill_by_name[true_skill_name]['TagID'], g_skill)
      end

      nil
    end

    # game8 => fandom
    UNIT_NAME_SUBSTITUTIONS = {
      "Caineghis: Gallia's Lion-King" => "Caineghis: Gallia's Lion King",
      'Corrin (F): Nightfall Ninja Act' => 'Corrin: Nightfall Ninja Act',
      'Corrin (M): Daylight Ninja Act' => 'Corrin: Daylight Ninja Act',
      'Corrin : Enjoying Tradition' => 'Corrin: Enjoying Tradition',
      'Dimitri: Sky Blue Lion' => 'Dimitri: Sky-Blue Lion',
      'Fiora: Defrosted Illian' => 'Fiora: Defrosted Ilian',
      "Hilda: Deer's Two Piece" => "Hilda: Deer's Two-Piece",
      'Leila: Rose Amid Fangs' => 'Leila: Rose amid Fangs',
      'Rennac: Rich Merchant' => 'Rennac: Rich &quot;Merchant&quot;',
      'Tharja: Normal Girl' => 'Tharja: &quot;Normal Girl&quot;',
      "Excellus: Conqueror's Wile" => 'Excellus: Conqueror’s Wile',
    }.freeze

    def retrieve_game8_unit_ratings
      unit_names = fandom.all_units_by_pagename.keys

      game8.all_units.each do |g_unit|
        unit_name = "#{g_unit['name']}: #{g_unit['title']}"
        next if unit_name == 'Kiran: Hero Summoner'

        next store_unit(unit_id(unit_name), g_unit) if unit_names.include?(unit_name)
        next store_unit(unit_id(UNIT_NAME_SUBSTITUTIONS[unit_name]), g_unit) if UNIT_NAME_SUBSTITUTIONS.key?(unit_name)

        true_unit_name, distance = unit_names.map { |name| [name, lev(name, unit_name)] }.min_by(&:last)
        if distance < 5
          errors[:unit_approximations] << { game8: unit_name, fandom: true_unit_name }
        else
          errors[:fandom_unit_not_found] << unit_name
          next
        end

        store_unit(unit_id(true_unit_name), g_unit)
      end

      nil
    end

    def export_game8_skill_ratings
      export_files(
        'skills-ratings-game8.json' => -> { exclude_game8_keys(all_skills) },
      )
    end

    def export_game8_seal_ratings
      export_files(
        'seals-ratings-game8.json' => -> { exclude_game8_keys(all_seals) },
      )
    end

    def export_game8_unit_ratings
      export_files(
        'units-ratings-game8.json' => -> { exclude_game8_keys(all_units) },
      )
    end

    def export_errors
      export_files(
        'errors.json' => :errors_report,
      )
    end

    def exclude_game8_keys(items)
      items.map { |item| item.except(:game8_id, :game8_name) }
    end

    def inspect
      "<#{self.class} @now=#{now}>"
    end

    private

    def boot
      @errors = empty_errors
      @all_units = []
      @all_units_by_id = nil
      @all_skills = []
      @all_skills_by_id = nil
      @all_seals = []
      @all_seals_by_id = nil
    end

    def empty_errors
      Hash.new { |h, k| h[k] = [] }
    end

    def errors_report
      {
        all: errors,
        game8: game8.errors,
        fandom: fandom.errors,
      }
    end

    # https://stackoverflow.com/a/50891978
    def lev(string1, string2, memo = {})
      return memo[[string1, string2]] if memo[[string1, string2]]
      return string2.size if string1.empty?
      return string1.size if string2.empty?

      min = [
        lev(string1.chop, string2, memo) + 1,
        lev(string1, string2.chop, memo) + 1,
        lev(string1.chop, string2.chop, memo) + (string1[-1] == string2[-1] ? 0 : 1),
      ].min
      memo[[string1, string2]] = min
      min
    end

    def skill_id_bis(name)
      fandom.all_skills_by_wikiname[name]['TagID']
    end

    def store_skill(id, g_skill, with_rating: true)
      res = {
        id:,
        game8_id: g_skill['game8_id'],
        game8_name: g_skill['game8_name'],
      }
      if with_rating
        if g_skill.key?('game8_rating')
          res.merge!(
            game8_rating: g_skill['game8_rating'] == '-' ? nil : g_skill['game8_rating'],
          )
        end
        res.merge!(
          g_skill.slice(
            'game8_grade',
          ),
        )
      end

      if g_skill['category'] == game8.class::SKILLS_S
        all_seals << res
      else
        all_skills << res
      end
    end

    def unit_id(name)
      fandom.all_units_by_pagename[name]['TagID']
    end

    def store_unit(id, g_unit)
      all_units << {
        id:,
        game8_id: g_unit['game8_id'],
        game8_name: g_unit['game8_name'],
      }.merge(
        game8_rating: g_unit['game8_rating'] == '-' ? nil : g_unit['game8_rating'],
      ).merge(
        g_unit.slice(
          'recommended_boon',
          'recommended_bane',
          'recommended_plus10',
        ),
      )
    end

    def fill_fandom_units_with_game8_data
      fandom.all_units.each do |f_unit|
        next if f_unit[:properties].include?('enemy')

        a_unit = all_units_by_id[f_unit['TagID']]
        next (errors[:game8_unit_not_found] << f_unit['WikiName']) if a_unit.nil?

        f_unit[:game8_id] = a_unit[:game8_id]
        f_unit[:game8_name] = a_unit[:game8_name]
      end
    end

    # in "index" pages
    GAME8_MISSING_SKILL_NAMES = [
      # weapons
      'Atlas+',
      # assists
      # "Maiden's Solace",
      # A skills
      # 'Spd/Res Solo 1',
      # B skills
      # "Yune's Whispers",
      'Seal Atk/Res 1',
      'Seal Atk/Res 2',
      # C skills
      'Spd/Res Oath 1',
      'Spd/Res Oath 2',
      'Spd/Res Oath 3',

      # Røkkr Sieges exclusive Special
      # 'Umbra Blast',
      # 'Umbra Burst',
      # 'Umbra Calamity',
      # 'Umbra Eruption',
    ].freeze

    def fill_fandom_skills_with_game8_data
      fandom.relevant_skills.each do |f_skill|
        next if GAME8_MISSING_SKILL_NAMES.include?(f_skill['Name']) # TODO: need update
        next if f_skill['Name'].include?('Falchion')
        next if f_skill[:fodder_details]&.all? { |desc| desc['WikiName'].include?('ENEMY') }

        f_id = f_skill[:base_id] || f_skill['TagID']
        a_skill = all_skills_by_id[f_id]
        next (errors[:game8_skill_not_found] << f_skill['WikiName']) if a_skill.nil?

        f_skill[:game8_id] = a_skill[:game8_id]
        f_skill[:game8_name] = a_skill[:game8_name]
      end
    end

    # in "index" pages
    GAME8_MISSING_SEAL_NAMES = [
      # too much to handle...
    ].freeze

    def fill_fandom_seals_with_game8_data
      fandom.all_seals.each do |f_seal|
        # next if GAME8_MISSING_SEAL_NAMES.include?(f_seal['Name'])

        a_seal = all_seals_by_id[f_seal['TagID']]
        if a_seal.nil?
          # next if f_seal['SP'] == '0' # sacred seals reducing dmg to 0
          next if f_seal['Name'].include?('Squad Ace')

          # errors[:game8_seal_not_found] << f_seal['WikiName']
          next
        end

        f_seal[:game8_id] = a_seal[:game8_id]
        f_seal[:game8_name] = a_seal[:game8_name]
      end
    end
  end
end
