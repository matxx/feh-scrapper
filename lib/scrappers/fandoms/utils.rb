# frozen_string_literal: true

require 'active_support/inflector/transliterate'

module Scrappers
  module Fandoms
    module Utils
      attr_reader :accents_table, :accents_table_regexp

      OBFUSCATED_KEYS = {
        fodder_lowest_rarity_when_obtained: :flrwo,
        fodder_lowest_rarity_for_inheritance: :flrfi,

        generic_summon_pool: :gsp,
        special_summon_pool: :ssp,
        heroic_grails: :hg,
        normal_divine_codes: :dc,
        limited_divine_codes: :ldc,
        focus_only: :foc,
      }.freeze

      # https://feheroes.fandom.com/wiki/Module:MF/data
      # https://github.com/alexbalandi/kannadb_remaster/blob/main/linus/feh/poro/poroAccents.py
      def setup_accents_table
        response = client.query titles: 'Module:MF/data', prop: :revisions, rvprop: :content
        content = response.data['pages'].first.last['revisions'][0]['*']
        subs = content.gsub(/[[:space:]]/, '').match(/\Areturn\{accents=\{(.*),\},\}\Z/)[1].split(',')
        @accents_table =
          subs.each_with_object({}) do |sub, hash|
            sub.match(/\A\["(.+)"\]="(.+)"\Z/) do |m|
              hash[m[1]] = m[2]
            end
          end
        @accents_table_regexp = Regexp.new(accents_table.keys.join)

        nil
      end

      # https://feheroes.fandom.com/wiki/Module:MF
      def pagename_to_wikiname(str)
        I18n
          .transliterate(
            str
            .gsub('&quot;', '')
            .gsub(accents_table_regexp, accents_table),
          )
          .gsub(/[^A-Za-z0-9 ._-]/, '')
      end

      # https://feheroes.fandom.com/wiki/Template:UnitWikiName?action=edit
      def unit_pagename_to_wikiname(str)
        pagename_to_wikiname(str)
      end

      # https://feheroes.fandom.com/wiki/Template:SkillWikiName?action=edit
      def skill_pagename_to_wikiname(str)
        pagename_to_wikiname(str).gsub('+', ' Plus')
      end

      def keys_for_is_in
        @keys_for_is_in ||= hash_for_is_in.keys
      end

      def hash_for_is_in
        {
          generic_summon_pool: false,
          special_summon_pool: false,
          heroic_grails: false,
          normal_divine_codes: false,
          limited_divine_codes: false,
          focus_only: false,
        }
      end

      def hash_for_lowest_rarity
        {
          generic_summon_pool: nil,
          special_summon_pool: nil,
          heroic_grails: nil,
          normal_divine_codes: nil,
          limited_divine_codes: nil,
          focus_only: nil,
        }
      end

      def obfuscate_keys(hash)
        hash.transform_keys { |k| OBFUSCATED_KEYS[k] }
      end
    end
  end
end
