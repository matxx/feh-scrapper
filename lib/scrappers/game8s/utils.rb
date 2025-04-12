# frozen_string_literal: true

module Scrappers
  module Game8s
    module Utils
      # if sanitization needed
      # https://github.com/alexbalandi/kannadb_remaster/blob/main/linus/feh/poro/poroAccents.py

      def game8_url(id)
        "https://game8.co/games/fire-emblem-heroes/archives/#{id}"
      end

      def extract_list(kind, html)
        dom = Nokogiri::HTML.parse(html)
        case kind
        when :skills_assist,
             :skills_special,
             :skills_a,
             :skills_b,
             :skills_c
          extract_list_skills(kind, dom)
        else
          send("extract_list_#{kind}", dom)
        end
      end

      MISSING_PAGES = [
        # '483497', # Future Focus : https://game8.co/games/fire-emblem-heroes/archives/483497
      ].freeze

      def extract_item(kind, html, item)
        return item if MISSING_PAGES.include?(item['game8_id'])

        dom = Nokogiri::HTML.parse(html)
        json =
          case kind
          when :skills_assist,
               :skills_a,
               :skills_b,
               :skills_c,
               :skills_x
            extract_item_skills(kind, dom, item)
          else
            send("extract_item_#{kind}", dom, item)
          end
        json.merge('category' => kind.to_s)
      end
    end
  end
end
