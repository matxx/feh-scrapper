# frozen_string_literal: true

require 'uri'

module Scrappers
  module Game8s
    module Units
      KIND_UNIT = :units

      PAGE_ID_UNITS = {
        KIND_UNIT => '242267', # https://game8.co/games/fire-emblem-heroes/archives/242267
      }.freeze

      # add page IDs of new units
      # that are not yet in the units list page yet
      # to extract them anyway
      PAGE_IDS_OF_NEW_UNITS = {
        KIND_UNIT => [],
      }.freeze

      def extract_list_units(dom)
        node = dom.at('h2:contains("List of All Heroes")')
        node = node.next_element until node.name == 'table'
        node.search('tbody tr').map { |tr| export_list_unit(tr) }
      end

      def export_list_unit(node)
        link = node.at('a').attr('href')
        uri = URI.parse(link)
        {
          'game8_id' => uri.path.split('/').last,
          'game8_name' => node.at('td:first-child').text.strip,
          'game8_rating' => node.at('td:last-child').text.strip,
        }
      end

      def extract_item_units(dom, item)
        para = dom.at('.a-paragraph:contains("This is a ranking page for the hero")')

        # "names" must be array-like : [nil, name, nil, title]
        names =
          case item['game8_id']
          when '267300'
            # https://game8.co/games/fire-emblem-heroes/archives/267300
            # missing text
            [nil, 'Camilla', nil, 'Tropical Beauty']
          when '401734'
            # https://game8.co/games/fire-emblem-heroes/archives/401734
            # error in title
            [nil, 'Yarne', nil, 'Hoppy New Year']
          else
            raise_with_item 'para not found' if para.nil?

            # ex : with double point - https://game8.co/games/fire-emblem-heroes/archives/470386
            para.text.match(/This is a ranking page for the hero (.+)( -|:) (.+) from the game/)
          end

        th = dom.at('th:contains("Overall Rating")')
        raise_with_item 'rating TH not found' if th.nil?
        rating = th.next_element.at('span').text
        if rating && item['game8_rating'] && rating != item['game8_rating']
          @errors[:unit_mismatch_in_ratings] << [item['game8_id'], rating, item['game8_rating']]
          # raise_with_item "mismatch in ratings : #{rating} VS #{item['game8_rating']}"
        end

        base = item.merge(
          'name' => names[1],
          'title' => names[3],
          'game8_rating' => rating, # prioritize the rating on "show" page
          # 'game8_rating' => item['game8_rating'] || rating, # prioritize the rating on "index" page
        )

        case item['game8_id']
        when '317540'
          # no IVs at all ! (Kiran)
          # https://game8.co/games/fire-emblem-heroes/archives/317540#hl_2
          return base.merge(
            'recommended_boon' => nil,
            'recommended_bane' => nil,
            'recommended_plus10' => nil,
          )
        when '492367'
          # missing header
          # https://game8.co/games/fire-emblem-heroes/archives/492367#hl_2
          return base.merge(
            'recommended_boon' => 'Def',
            'recommended_bane' => 'Spd',
            'recommended_plus10' => 'Def',
          )
        when '488074', '488073', '526831'
          # TODO: handle several recommended "no merge" and "+10" builds...
          # https://game8.co/games/fire-emblem-heroes/archives/488074#hl_2
          # https://game8.co/games/fire-emblem-heroes/archives/488073#hl_2
          # https://game8.co/games/fire-emblem-heroes/archives/526831
          return base.merge(
            'recommended_boon' => nil,
            'recommended_bane' => nil,
            'recommended_plus10' => nil,
          )
        when '534611'
          # TODO: handle several recommended "no merge" and "+10" builds...
          # https://game8.co/games/fire-emblem-heroes/archives/534611
          return base.merge(
            'recommended_boon' => nil,
            'recommended_bane' => 'Spd',
            'recommended_plus10' => nil,
          )
        when '267183', '356374'
          # TODO: handle several recommended "no merge" builds...
          # https://game8.co/games/fire-emblem-heroes/archives/267183#hl_2
          # https://game8.co/games/fire-emblem-heroes/archives/356374#hl_2
          return base.merge(
            'recommended_boon' => nil,
            'recommended_bane' => nil,
            'recommended_plus10' => 'Spd',
          )
        when '267455'
          # TODO: handle several recommended "no merge" builds...
          # https://game8.co/games/fire-emblem-heroes/archives/267455#hl_2
          return base.merge(
            'recommended_boon' => nil,
            'recommended_bane' => nil,
            'recommended_plus10' => 'Atk',
          )
        when '376961'
          # TODO: handle several recommended "+10" builds...
          # https://game8.co/games/fire-emblem-heroes/archives/376961#hl_2
          return base.merge(
            'recommended_boon' => 'Spd',
            'recommended_bane' => 'Atk',
            'recommended_plus10' => nil,
          )
        when '267295'
          # TODO: handle several recommended "+10" builds...
          # https://game8.co/games/fire-emblem-heroes/archives/267295#hl_2
          return base.merge(
            'recommended_boon' => 'Atk',
            'recommended_bane' => 'HP',
            'recommended_plus10' => nil,
          )
        when '505100'
          # TODO: handle several recommended "+10" builds...
          # https://game8.co/games/fire-emblem-heroes/archives/267295#hl_2
          return base.merge(
            'recommended_boon' => 'Atk',
            'recommended_bane' => 'Spd',
            'recommended_plus10' => nil,
          )
        when '267095'
          # https://game8.co/games/fire-emblem-heroes/archives/267095#hl_2
          return base.merge(
            'recommended_boon' => 'none',
            'recommended_bane' => 'none',
            'recommended_plus10' => 'Spd',
          )
        end

        # multiple same headers
        # ex : https://game8.co/games/fire-emblem-heroes/archives/269116#hl_2
        header = dom.search('h3:contains("Recommended IVs")').last

        node = header.next_element
        node = node.next_element until node.nil? || node.name.start_with?('h')
        raise_with_item 'no following header ?' if node.nil?

        # ex : https://game8.co/games/fire-emblem-heroes/archives/473591#hl_2
        if node.name == 'h4' && node.text == 'Neutral IVs by default!'
          node = node.next_element
          node = node.next_element until node.nil? || node.name.start_with?('h')
        end

        ivs = nil
        plus10 = nil

        case node.name
        when 'h2'
          # no recommended IV's
          # ex : https://game8.co/games/fire-emblem-heroes/archives/331614#hl_2

        when 'h3', 'h4'
          # ex : h4 - https://game8.co/games/fire-emblem-heroes/archives/270352#hl_2
          # ex : h3 - https://game8.co/games/fire-emblem-heroes/archives/436733#hl_2

          case item['game8_id']
          when '267857'
            # https://game8.co/games/fire-emblem-heroes/archives/267857#hl_2
            # header missing
            ivs = [nil, 'Spd', nil, 'Def']
            node = node.previous_element
          when '415891'
            # https://game8.co/games/fire-emblem-heroes/archives/415891#hl_2
            # header missing
            ivs = [nil, 'Spd', nil, 'Res']
            plus10 = [nil, 'Spd']
          else
            # ex : https://game8.co/games/fire-emblem-heroes/archives/279315#hl_2
            # ex : https://game8.co/games/fire-emblem-heroes/archives/267280#hl_2
            if node.text.start_with?('Base Stats') ||
               node.text.start_with?('Neutral Stats')
              ivs = [nil, 'none', nil, 'none']
            else
              # ex: no minus - https://game8.co/games/fire-emblem-heroes/archives/463869#hl_2
              # ex: "!" - https://game8.co/games/fire-emblem-heroes/archives/284213#hl_2
              # ex: spaces - https://game8.co/games/fire-emblem-heroes/archives/351518#hl_2
              ivs = node.text.match(%r{\A\+ ?(.+?) ?(/|and) ?-? ?(.+?)!?\Z})
              raise_with_item 'no IV match ?' if ivs.nil?
            end
          end

          node = node.next_element
          node = node.next_element until node.nil? || node.name.start_with?('h')
          raise_with_item 'no following header ? (2)' if node.nil?

          case node.name
          when 'h2'
            # no recommended +10
            # ex : https://game8.co/games/fire-emblem-heroes/archives/270352#hl_2
          when 'h3', 'h4'
            # ex : h3 - https://game8.co/games/fire-emblem-heroes/archives/436733#hl_2
            # ex : h4 - https://game8.co/games/fire-emblem-heroes/archives/391618#hl_2

            # ex : "M" - https://game8.co/games/fire-emblem-heroes/archives/436734#hl_2
            # ex : "Merge Project" - https://game8.co/games/fire-emblem-heroes/archives/267350#hl_2
            # ex : "Merge project" - https://game8.co/games/fire-emblem-heroes/archives/279313#hl_2
            # ex : "with" - https://game8.co/games/fire-emblem-heroes/archives/275278#hl_2
            # ex : "IV" - https://game8.co/games/fire-emblem-heroes/archives/275291#hl_2
            plus10 = node.text.match(/\A\+(.+?) (IV )?(for|with)( a)? \+?10 [Mm]erge( [Pp]roject)?\.?\Z/)
            # ex : https://game8.co/games/fire-emblem-heroes/archives/275316#hl_2
            # ex : https://game8.co/games/fire-emblem-heroes/archives/275368#hl_2
            plus10 ||= node.text.match(/\A\+(.+?) if (you want|doing) (to|a \+10) merge\Z/)
            # ex : https://game8.co/games/fire-emblem-heroes/archives/275483#hl_2
            plus10 ||= node.text.match(/\A\+(.+?) For \+10 Merges\Z/)
            # ex : https://game8.co/games/fire-emblem-heroes/archives/275877#hl_2
            plus10 ||= node.text.match(/\A\+(.+?) if doing a \+10 Merge Project\Z/)

            # no recommended IVs for +10 merge
            # https://game8.co/games/fire-emblem-heroes/archives/267256#hl_2
            # https://game8.co/games/fire-emblem-heroes/archives/267197#hl_2
            if plus10.nil? && !['267256', '267197', '267221'].include?(item['game8_id'])
              raise_with_item 'no +10 match ?'
            end
          else
            raise_with_item "following header is #{node.name} ? (2)"
          end
        else
          raise_with_item "following header is #{node.name} ?"
        end

        case item['game8_id']
        when '356376'
          # https://game8.co/games/fire-emblem-heroes/archives/356376#hl_2
          # header marked as <p>
          ivs = [nil, 'Spd', nil, 'HP']
          plus10 = [nil, 'Spd']
        when '356375'
          # https://game8.co/games/fire-emblem-heroes/archives/356375#hl_2
          # IVs not in right spot and as <p>
          ivs = [nil, 'Spd', nil, 'Res']
          plus10 = [nil, 'Spd']
        end

        recommended_boon = sanitize_iv(ivs[1]) if ivs
        recommended_bane = sanitize_iv(ivs[3]) if ivs
        recommended_plus10 = sanitize_iv(plus10[1]) if plus10

        base.merge(
          'recommended_boon' => recommended_boon,
          'recommended_bane' => recommended_bane,
          'recommended_plus10' => recommended_plus10,
        )
      end

      def sanitize_iv(stat)
        iv = stat.strip
        return if iv.nil?
        return iv if ['HP', 'Atk', 'Spd', 'Def', 'Res', 'none'].include?(iv)
        return 'HP' if iv == 'Hp'

        raise_with_item "unknown iv : #{iv}"
      end
    end
  end
end
