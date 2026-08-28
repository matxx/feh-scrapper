# frozen_string_literal: true

module Scrappers
  module Fandoms
    module BannerFocuses
      attr_reader(
        :all_banner_focuses,
        :all_banner_focuses_by_pagename,
        :all_summoning_events,
        :all_summoning_events_by_wikiname,
      )

      def reset_all_banners!
        @all_banner_focuses = nil
        @all_banner_focuses_by_pagename = nil
        @all_summoning_events = nil
        @all_summoning_events_by_wikiname = nil
      end

      # https://feheroes.fandom.com/wiki/Special:CargoTables/SummoningEventFocuses
      def scrap_banner_focuses
        return if all_banner_focuses

        fields = [
          '_pageName=Page',
          'WikiName',
          'Unit',
          'Rarity',
        ]

        @all_banner_focuses = retrieve_all_pages('SummoningEventFocuses', fields)
        @all_banner_focuses_by_pagename = all_banner_focuses.group_by { |x| x['Page'] }

        nil
      end

      # https://feheroes.fandom.com/wiki/Special:CargoTables/SummoningEvents
      # WikiName is the same value used by SummoningEventFocuses rows, it lets us
      # attach a start/end date to each banner (a Page can have several
      # SummoningEvents rows, ex: multiple EventTypes for the same banner)
      def scrap_summoning_events
        return if all_summoning_events

        fields = [
          # '_pageName=Page',
          'WikiName',
          # 'Name',
          'StartTime',
          'EndTime',
          # 'EventType',
        ]

        @all_summoning_events = retrieve_all_pages('SummoningEvents', fields)
        @all_summoning_events_by_wikiname = all_summoning_events.index_by { |x| x['WikiName'] }

        nil
      end

      def export_banners
        export_files(
          'banners.json' => :banners_as_json,
        )
      end

      private

      def banners_as_json
        all_banner_focuses_by_pagename.map do |name, rows|
          sanitized_name =
            name
            .gsub('&quot;', '"')
            .gsub('&amp;', '&')
            .gsub(/ \(Focus\)\Z/, '')
            .gsub('A Monstrous Harvest', 'A Monstrous Harvest / Treat Fiends') # banner has been renamed after its first appearance

          events = rows.map { |row| row['WikiName'] }.uniq.filter_map do |wikiname|
            event = all_summoning_events_by_wikiname[wikiname]
            @errors[:banner_focus_summoning_event_not_found] << wikiname if event.nil?
            event
          end

          {
            name: sanitized_name,
            start_time: events.map { |event| event['StartTime'] }.min,
            end_time: events.map { |event| event['EndTime'] }.max,
            unit_ids: rows.map do |row|
              unit = all_units_by_wikiname[row['Unit']]
              if unit.nil?
                @errors[:unit_on_banner_focus_not_found] << row
                next
              end

              unit['TagID']
            end.uniq.compact.sort,
          }
        end.sort_by { |banner| [banner[:start_time] || '', banner[:name]] }
      end
    end
  end
end
