# frozen_string_literal: true

module Scrappers
  module Game8s
    module Skills
      SKILLS_S = 'skills_s'

      PAGE_ID_SKILLS = {
        skills_weapon:  '265412', # https://game8.co/games/fire-emblem-heroes/archives/265412
        skills_assist:  '265413', # https://game8.co/games/fire-emblem-heroes/archives/265413
        skills_special: '265414', # https://game8.co/games/fire-emblem-heroes/archives/265414
        skills_a: '265416', # https://game8.co/games/fire-emblem-heroes/archives/265416
        skills_b: '265417', # https://game8.co/games/fire-emblem-heroes/archives/265417
        skills_c: '265418', # https://game8.co/games/fire-emblem-heroes/archives/265418
        skills_s: '267543', # https://game8.co/games/fire-emblem-heroes/archives/267543
        skills_x: '430372', # https://game8.co/games/fire-emblem-heroes/archives/430372
      }.freeze

      # add page IDs of new skills
      # that are not yet in the skills lists page yet
      # to extract them anyway
      PAGE_IDS_OF_NEW_SKILLS = {
        skills_weapon: [],
        skills_assist: [],
        skills_special: [],
        skills_a: ['512297', '512298', '512296'], # Atk/Spd Tidings | Primordial Boost | Trample
        skills_b: [],
        skills_c: [],
        skills_s: [],
        skills_x: [],
      }.freeze

      EXTRACT = {
        skills_assist: [
          'game8_name',
          'sp',
          'range',
          'effect',
          'game8_rating',
        ],
        skills_special: [
          'game8_name',
          'effect',
          'sp',
          'game8_rating',
        ],
        skills_a: [
          'game8_name',
          'effect',
          'sp',
          'game8_rating',
        ],
        skills_b: [
          'game8_name',
          'effect',
          'sp',
          'game8_rating',
        ],
        skills_c: [
          'game8_name',
          'effect',
          'sp',
          'game8_rating',
        ],
      }.freeze

      def extract_list_skills_weapon(dom)
        dom.search('th:contains("Skill Name")').flat_map do |node|
          table = node
          table = table.parent until table.name == 'table'
          table.search('tbody tr').map { |tr| export_list_skill_weapon(tr) }
        end
      end

      def export_list_skill_weapon(node)
        link = node.at('a').attr('href')
        tds = node.children.select { |child| child.name == 'td' }
        {
          'game8_id' => link.split('/').last,
          'game8_name' => tds[0].text.strip,
          'kind' => node.at('img').attr('alt').gsub(/ Icon\Z/, ''),
          'mt' => tds[1].text.strip,
          'effect' => tds[2].text.strip,
          'sp' => tds[3].text.strip,
        }
      end

      def extract_list_skills(kind, dom)
        dom.search('th:contains("Skill Name")').flat_map do |node|
          table = node
          table = table.parent until table.name == 'table'
          table_kind = table.previous_sibling
          table_kind = table_kind.previous_sibling until table_kind.name == 'table'
          subkind = table_kind.at('.a-bold').text
          table.search('tbody tr').map { |tr| export_list_skill(kind, subkind, tr) }
        end
      end

      def export_list_skill(kind, subkind, node)
        link = node.at('a').attr('href')
        tds = node.children.select { |child| child.name == 'td' }
        EXTRACT[kind]
          .each_with_object({}).with_index do |(key, hash), index|
            hash[key] = tds[index].text.strip
            hash[key] = nil if key == 'game8_rating' && ['', '-'].include?(hash[key])
          end
          .merge(
            'game8_id' => link.split('/').last,
            'kind' => subkind,
          )
      end

      def extract_list_skills_x(dom)
        dom.search('th:contains("Skill Name")').flat_map do |node|
          table = node
          table = table.parent until table.name == 'table'
          table.search('tbody tr').map { |tr| export_list_skill_x(tr) }
        end
      end

      def export_list_skill_x(node)
        link = node.at('a').attr('href')
        tds = node.children.select { |child| child.name == 'td' }
        {
          'game8_id' => link.split('/').last,
          'game8_name' => tds[0].text.strip,
          'effect' => tds[1].text.strip,
        }
      end

      def extract_list_skills_s(dom)
        table = dom.at('th:contains("Sacred Seal")')
        table = table.parent until table.name == 'table'
        table.search('tbody tr').map { |tr| export_list_sacred_seal(tr) }
      end

      def export_list_sacred_seal(node)
        link = node.at('a').attr('href')
        tds = node.children.select { |child| child.name == 'td' }

        name = tds[0].text.strip

        node_how_to_obtain = tds[2].at('.a-bold')
        how_to_obtain =
          if node_how_to_obtain
            node_how_to_obtain.text
          else
            enhancement = tds[2].at('.align')
            raise_with_item "no enhancement ? #{name}" if enhancement.nil?

            case enhancement.text.strip.gsub(/\s+/, ' ')
            when '×20 ×100 ×40', '×20 ×100 ×20'
              'Available through Sacred Seal Creation'
            when '×400 ×1000 ×100'
              'Can be obtained through Sacred Seal Enhancement'
            else
              raise_with_item "weird enhancement ? #{name}"
            end
          end

        {
          'game8_id' => link.split('/').last,
          'game8_name' => name,
          'game8_grade' => tds[1].text.strip,
          'how_to_obtain' => how_to_obtain,
          'effect' => tds[2].at('hr').next_sibling.text,
        }
      end

      def extract_rating_and_grade(dom)
        header = dom.at('th:contains("Rating")')
        td_rating = header.next_element
        raise_with_item 'not a td ? (td_rating)' unless td_rating.name == 'td'

        m = td_rating.text.match(%r{\A(.*?)/10\.0\Z})
        raise_with_item "rating not found : #{td_rating.text}" if m.nil?

        rating = m[1]
        rating = nil if rating == ''

        th_ranking = td_rating.next_element
        raise_with_item 'not a th ? (ranking)' unless th_ranking.name == 'th'
        raise_with_item 'not th ranking ? (ranking)' unless th_ranking.text == 'Ranking'

        td_grade = th_ranking.next_element
        raise_with_item 'not a td ? (grade)' unless td_grade.name == 'td'

        {
          'game8_rating' => rating,
          'game8_grade' => extract_grade(td_grade),
        }
      end

      def extract_grade(container)
        img = container.at('img')
        grade =
          if img
            img.attr('alt').gsub(/ Rank( Icon)?\Z/, '')
          else
            text = container.text.strip
            case text
            when '', 'Unranked'
              nil
            else
              raise_with_item "unknow grade : #{text}"
            end
          end
        raise_with_item "no td grade ? #{grade}" if grade && !['SS', 'S', 'A', 'B', 'C'].include?(grade)

        grade
      end

      # https://game8.co/games/fire-emblem-heroes/archives/336708
      MISSING_WEAPON_RANGE_1_IDS = ['325371', '336708', '411499', '492391', '492392', '492393'].freeze
      MISSING_WEAPON_RANGE_2_IDS = ['314401', '327121', '492394', '492395', '492396'].freeze
      def extract_item_skills_weapon(dom, item)
        fill_missing_name(dom, item)

        # some pages are missing
        # https://game8.co/games/fire-emblem-heroes/archives/417551
        # lets use the wiki !
        # https://feheroes.fandom.com/wiki/Father%27s-Son_Axe
        case item['game8_id']
        when '417550', '417551'
          return item.merge(
            'range' => 1,
            'game8_rating' => nil,
            'game8_grade' => nil,
          )
        end

        header = dom.at('h3:contains("Basic Information")')
        table = header.next_element
        raise_with_item 'not a table ?' unless table.name == 'table'

        th = table.at('th:contains("Range")')
        td_range = th.next_element
        raise_with_item 'not a td ? (td_range)' unless td_range.name == 'td'

        case item['game8_id']
        when *MISSING_WEAPON_RANGE_1_IDS
          range = 1
        when *MISSING_WEAPON_RANGE_2_IDS
          range = 2
        else
          range = td_range.text.to_i
          raise_with_item "weird range : #{range}" unless [1, 2].include?(range)
        end

        item
          .merge(extract_rating_and_grade(dom))
          .merge('range' => range)
      end

      PAGE_IDS_WITH_RATING_MISMATCH = [
        # '355161',
      ].freeze

      def extract_item_skills(_kind, dom, item)
        fill_missing_name(dom, item)

        res = extract_rating_and_grade(dom)

        # handle mismatch in ratings
        # ex: "Holy Ground" is rated 9.0 on "index" but 9.5 on "show"
        # (the "show" was not updated after the release of "Holy Ground+")
        rating1 = item['game8_rating']
        rating2 = res['game8_rating']
        if rating1 && rating2 && rating1 != rating2 && !PAGE_IDS_WITH_RATING_MISMATCH.include?(item['game8_id'])
          @errors[:skill_mismatch_in_ratings] << [item['game8_id'], rating1, rating2]
        end

        # prioritize the rating on "index" page
        res.merge(item) { |_k, v_old, v_new| v_new || v_old }
      end

      def extract_item_skills_special(dom, item)
        fill_missing_name(dom, item)

        th = dom.at('th:contains("Cooldown")')
        td = th.next_element
        raise_with_item 'not a td ?' unless td.name == 'td'

        text = td.text.strip
        raise_with_item "not integer ? #{text}" unless text.match(/\A\d+\Z/)

        item
          .merge(extract_rating_and_grade(dom))
          .merge('cooldown' => text.to_i)
      end

      # nothing more to extract
      def extract_item_skills_s(_dom, item)
        item
      end

      def extract_item_skills_s_useless(dom, item)
        case item['game8_id']
        when '266266', '266752'
          # sacred seal link is in fact the passive skill with same name...
          # https://game8.co/games/fire-emblem-heroes/archives/266266
          return item
        when '291556', '291568', '291598', '291710'
          # rating not extractable
          # https://game8.co/games/fire-emblem-heroes/archives/291556
          return item
        end

        header = dom.at('th:contains("Rating")')
        td_grade = header.next_element
        raise_with_item 'not a td ? (td_grade)' unless td_grade.name == 'td'

        header = dom.at('th:contains("Effect")')
        td_effect = header.next_element
        raise_with_item 'not a td ? (td_effect)' unless td_effect.name == 'td'

        # too many mismatch...
        # grade1 = item['game8_grade']
        # grade2 = extract_grade(td_grade)
        # unless grade1 == grade2
        #   raise_with_item "mismatch in grade : #{grade1} VS #{grade2}"
        # end

        # too many mismatch...
        # effect1 = item['effect'].strip
        # effect2 = td_effect.text.strip
        # unless effect1 == effect2
        #   raise_with_item "mismatch in effect : #{effect1} VS #{effect2}"
        # end

        item
          .merge('game8_grade' => extract_grade(td_grade))
          .merge('effect' => td_effect.text.strip)
      end

      private

      def fill_missing_name(dom, item)
        return if item['game8_name']

        # typos in names...
        # ex :
        # - https://game8.co/games/fire-emblem-heroes/archives/267862
        # - https://game8.co/games/fire-emblem-heroes/archives/353238
        # - https://game8.co/games/fire-emblem-heroes/archives/265462
        names = [
          extract_name_from_page_title(dom),
          extract_name_from_skill_family(dom),
          extract_name_from_basic_information(dom),
        ].compact
        name = names.group_by(&:itself).max_by { |_, items| items.size }.first
        raise_with_item 'no name ?' if name.nil?

        item['game8_name'] = name

        # if item['game8_name'] && item['game8_name'] != name
        #   @errors[:skill_name_mismatch] << [item['game8_id'], name, item['game8_name']]
        # end

        # name

        nil
      end

      # can not be used first because some pages do not have any pattern in title
      # ex : https://game8.co/games/fire-emblem-heroes/archives/266192
      def extract_name_from_page_title(dom)
        title = dom.at('html head title').text.strip
        raise_with_item 'no title ?' if title.empty?

        name = nil
        [
          /\AWhich Heroes Have the Skill ([^?]+)\?/,
          /\AWho Has the Skill ([^?]+)\?/,
          /\A([^:]+): Best Fodder/,
        ].each do |regexp|
          m = title.match(regexp)
          next if m.nil?

          name = m[1].strip
        end
        return if name.nil?

        # ex : https://game8.co/games/fire-emblem-heroes/archives/451143
        return if name.include?('|')

        name
      end

      # ex w/o : https://game8.co/games/fire-emblem-heroes/archives/265687
      def extract_name_from_skill_family(dom)
        header = dom.at('h3:contains("Skill Family")')
        return if header.nil?

        table = header.next_element
        raise_with_item 'not a table ?' unless table.name == 'table'

        b = table.at('td b.a-bold')
        text =
          if b
            b.text
          else
            # ex: https://game8.co/games/fire-emblem-heroes/archives/503882
            tds = table.css('td')
            tds[0].text if tds.size == 1
          end
        # ex: https://game8.co/games/fire-emblem-heroes/archives/507104
        # not a single links in the 4 "blue skies" skills
        return if text.nil?

        name = text.strip
        raise_with_item 'no name ?' if name.empty?

        name
      end

      # ex w/o : https://game8.co/games/fire-emblem-heroes/archives/265687
      def extract_name_from_basic_information(dom)
        header = dom.at('h3:contains("Basic Information")')
        raise_with_item 'no header ?' if header.nil?

        table = header.next_element
        raise_with_item 'not a table ?' unless table.name == 'table'

        th = table.at('th:contains("Skill")')
        return if th.nil?

        td = th.next_element
        raise_with_item 'not a td ?' unless td.name == 'td'

        name = td.text.strip
        raise_with_item 'no name ?' if name.empty?

        name
      end
    end
  end
end
