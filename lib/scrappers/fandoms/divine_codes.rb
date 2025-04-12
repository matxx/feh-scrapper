# frozen_string_literal: true

require 'active_support/core_ext/string/conversions'

module Scrappers
  module Fandoms
    module DivineCodes
      attr_reader(
        :divine_codes,
        :divine_codes_by_unit_pagename,
        :divine_codes_by_unit_wikiname,
      )

      def reset_divine_codes!
        @divine_codes = nil
        @divine_codes_by_unit_pagename = nil
        @divine_codes_by_unit_wikiname = nil
      end

      # https://feheroes.fandom.com/wiki/Combat_Manuals
      def scrap_divine_codes
        return if divine_codes

        response = client.query titles: 'Combat Manuals', prop: :revisions, rvprop: :content
        lines = response.data['pages'].first.last['revisions'][0]['*'].split("\n")

        @divine_codes = { normal: {}, limited: {} }
        @divine_codes_by_unit_pagename = {}
        @divine_codes_by_unit_wikiname = {}

        index = 0
        regexp_header_section = /===Normal( (\d))?===/
        regexp_header_table = /\A\|\+ (.*)\Z/
        unit_regexp = /\{unit=([^;]+);rarity=([^;]+);cost=([^\}]+)\}/
        prefix = '[divide_codes][normal]'
        loop do
          index += 1 until lines[index].nil? || (m = lines[index].match(regexp_header_section))
          break if lines[index].nil?

          divine_codes_number = m[2].nil? ? 1 : m[2].to_i
          divine_codes[:normal][divine_codes_number] = {}
          prefix_number = "#{prefix}[#{divine_codes_number}]"

          logger.info "-- processing number : #{divine_codes_number}"

          index += 1
          loop do
            index += 1 until lines[index].nil? || (m1 = lines[index].match(/#{regexp_header_section}|===Limited-time===/)) || (m2 = lines[index].match(regexp_header_table))
            break if m1
            raise %(#{prefix_number} title not found : #{divine_codes_number}) if lines[index].nil?

            title_name = m2[1]
            prefix_title = "#{prefix_number}[#{title_name}]"

            logger.info "-- processing title : #{title_name}"

            item_index = index
            item_index += 1 until lines[item_index].nil? || lines[item_index].include?('item=')
            if lines[item_index].nil?
              raise %(#{prefix_title} lines with "item=" not found for number : #{divine_codes_number})
            end

            m = lines[item_index].match(/\|item=(Divine Code: Part (\d))/)
            raise %(#{prefix_title} "item" not matching for number : #{divine_codes_number}) if m.nil?
            unless divine_codes_number == m[2].to_i
              raise %{#{prefix_title} "item" mismatch : `#{lines[item_index]}` (title : #{divine_codes_number} VS row #{m[2]})}
            end

            item_name = m[1]
            divine_codes[:normal][divine_codes_number]['item'] = item_name

            manuals_index = index
            manuals_index += 1 until lines[manuals_index].nil? || lines[manuals_index].include?('manuals=')
            if lines[manuals_index].nil?
              raise %(#{prefix_title} lines with "manuals=" not found for number : #{divine_codes_number})
            end

            ['start'].each do |bound|
              bound_index = index
              bound_index += 1 until lines[bound_index].nil? || lines[bound_index].include?("#{bound}=")
              if lines[bound_index].nil?
                raise %(#{prefix_title} lines with "#{bound}=" not found for number : #{divine_codes_number})
              end
              if bound_index > manuals_index
                raise %(#{prefix_title} lines with "#{bound}=" too far : #{bound_index} > #{manuals_index})
              end

              line = lines[bound_index]
              m = line.match(/\|#{bound}=(.*)\Z/)
              raise %(#{prefix_title} "#{bound}=" mismatch for number #{divine_codes_number} : #{line}) if m.nil?

              divine_codes[:normal][divine_codes_number]["#{bound}_time"] = m[1].to_time
            end

            divine_codes[:normal][divine_codes_number]['units'] = []
            (1..5).to_a.each do |idx|
              m = lines[manuals_index + idx].match(unit_regexp)
              raise "#{prefix_title} line not matching : #{lines[manuals_index + idx]}" if m.nil?

              pagename = m[1]
              wikiname = pagename_to_wikiname(pagename)
              rarity = m[2].to_i
              cost = m[3].to_i

              divine_codes[:normal][divine_codes_number]['units'] << {
                unit: pagename,
                title: title_name,
                rarity:,
                cost:,
              }
              details = {
                kind: :normal,
                name: item_name,
                number: divine_codes_number,
                title: title_name,
                rarity:,
                cost:,
              }
              divine_codes_by_unit_pagename[pagename] ||= []
              divine_codes_by_unit_pagename[pagename] << details
              divine_codes_by_unit_wikiname[wikiname] ||= []
              divine_codes_by_unit_wikiname[wikiname] << details
            end

            index = manuals_index + 6
          end

          logger.info "-- number done : #{divine_codes_number}"
        end

        prefix = '[divide_codes][limited]'
        regexp_header_table = /\A\|\+ (\d{4})\Z/

        index = 0
        index += 1 until lines[index].nil? || lines[index] == '===Limited-time==='
        raise "#{prefix} header not found" if lines[index].nil?

        loop do
          index += 1 until lines[index].nil? || (m = lines[index].match(regexp_header_table))
          break if lines[index].nil?

          year = m[1].to_i
          divine_codes[:limited][year] = {}
          prefix_year = "#{prefix}[#{year}]"

          logger.info "-- processing year : #{year}"

          loop do
            item_index = index
            item_index += 1 until lines[item_index].nil? || lines[item_index].include?('item=')
            break if lines[item_index].nil?

            # raise %{#{prefix_year} lines with "item=" not found for year : #{year}} if lines[item_index].nil?

            m = lines[item_index].match(/\|item=(Divine Code: Ephemera (\d+))/)
            raise %(#{prefix_year} "item" not matching for year : #{year}) if m.nil?

            item_name = m[1]
            month = m[2].to_i
            prefix_month = "#{prefix_year}[#{month}]"

            logger.info "-- processing month : #{month}"

            divine_codes[:limited][year][month] = {}
            divine_codes[:limited][year][month]['item'] = item_name

            manuals_index = index
            manuals_index += 1 until lines[manuals_index].nil? || lines[manuals_index].include?('manuals=')
            raise %(#{prefix_month} lines with "manuals=" not found for year : #{year}) if lines[manuals_index].nil?

            ['start', 'end'].each do |bound|
              bound_index = index
              bound_index += 1 until lines[bound_index].nil? || lines[bound_index].include?("#{bound}=")
              raise %(#{prefix_month} lines with "#{bound}=" not found for year : #{year}) if lines[bound_index].nil?
              raise %(#{prefix_month} lines with "#{bound}=" too far : #{bound_index} > #{manuals_index}) if bound_index > manuals_index

              line = lines[bound_index]
              m = line.match(/\|#{bound}=(.*)\Z/)
              raise %(#{prefix_month} "#{bound}=" mismatch for year #{year} : #{line}) if m.nil?

              divine_codes[:limited][year][month]["#{bound}_time"] = m[1].to_time
            end

            divine_codes[:limited][year][month]['units'] = []
            index = manuals_index
            loop do
              until lines[index].nil? ||
                    (m1 = lines[index].match(/\A\](\}\})?\Z/)) ||
                    (m2 = lines[index].match(unit_regexp))
                index += 1
              end
              break if m1
              raise "#{prefix_month} end not found (year: #{year}, month: #{month})" if lines[index].nil?

              pagename = m2[1]
              wikiname = pagename_to_wikiname(pagename)
              rarity = m2[2].to_i
              cost = m2[3].to_i

              divine_codes[:limited][year][month]['units'] << {
                unit: pagename,
                rarity:,
                cost:,
              }
              details = {
                kind: :limited,
                name: item_name,
                year:,
                month:,
                rarity:,
                cost:,
              }
              divine_codes_by_unit_pagename[pagename] ||= []
              divine_codes_by_unit_pagename[pagename] << details
              divine_codes_by_unit_wikiname[wikiname] ||= []
              divine_codes_by_unit_wikiname[wikiname] << details

              index += 1
            end

            logger.info "-- month done : #{month}"

            break if month == 12
          end

          logger.info "-- year done : #{year}"
        end

        nil
      end

      def units_that_appeared_multiple_times_as_five_stars
        divine_codes_by_unit_pagename.select { |_a, b| b.count { |x| x[:rarity] == 5 } > 1 }
      end
    end
  end
end
