# frozen_string_literal: true

module Scrappers
  module Fandoms
    module Images
      attr_reader :all_images_by_pagename

      # Too many values supplied for parameter "titles". The limit is 50. (toomanyvalues) (MediawikiApi::ApiError)
      MAX_TITLES_SIZE = 50

      def reset_all_images_by_pagename!
        @all_images_by_pagename = nil
      end

      def scrap_all_images
        return if all_images_by_pagename

        @all_images_by_pagename = {}

        # unit portraits
        all_units.each_slice(MAX_TITLES_SIZE).each do |units|
          titles = units.map { |unit| unit_face_img(unit) }
          retrieve_images(titles)
        end

        # chosen unit icons
        titles =
          ['Fire', 'Water', 'Wind', 'Earth']
          .map { |element| "File:Chosen Effect #{element}.png" }
        retrieve_images(titles)

        # legendary unit icons
        titles =
          ['Fire', 'Water', 'Wind', 'Earth']
          .map { |element| "File:Legendary Effect #{element}.png" }
        retrieve_images(titles)

        # mythic unit icons
        titles =
          ['Light', 'Dark', 'Astra', 'Anima']
          .product(['', ' 02', ' 03'])
          .flat_map { |element, suffix| "File:Mythic Effect #{element}#{suffix}.png" }
        retrieve_images(titles)

        # skill icons
        all_skills.each_slice(MAX_TITLES_SIZE).each do |skills|
          titles = skills.map { |skill| skill_icon(skill) }
          retrieve_images(titles)
        end

        # seal icons
        all_seals.each_slice(MAX_TITLES_SIZE).each do |skills|
          titles = skills.map { |skill| skill_icon(skill) }
          retrieve_images(titles)
        end

        nil
      end

      def fill_units_with_images
        all_units.each do |unit|
          unit[:image_url_for_portrait] = all_images_by_pagename[unit_face_img(unit)]

          if unit[:properties].include?('chosen')
            title = image_url_for_icon_chosen(unit)
            unit[:image_url_for_icon_chosen] = all_images_by_pagename[title]
          end
          if unit[:properties].include?('legendary')
            title = image_url_for_icon_legendary(unit)
            unit[:image_url_for_icon_legendary] = all_images_by_pagename[title]
          end
          if unit[:properties].include?('mythic')
            title = image_url_for_icon_mythic(unit)
            unit[:image_url_for_icon_mythic] = all_images_by_pagename[title]
          end
        end

        nil
      end

      def fill_skills_with_images
        all_skills.each do |skill|
          skill[:image_url] = all_images_by_pagename[skill_icon(skill)]
        end

        nil
      end

      def fill_seals_with_images
        all_seals.each do |seal|
          seal[:image_url] = all_images_by_pagename[skill_icon(seal)]
        end

        nil
      end

      private

      def retrieve_images(titles)
        response = client.query(format: :json, prop: :imageinfo, iiprop: :url, titles:)
        response.data['pages'].each_value do |data|
          next if data['imageinfo'].nil?

          all_images_by_pagename[data['title']] =
            data['imageinfo'][0]['url'].gsub(%r{https://static\.}, 'https://vignette.')
        end
      end

      def unit_face_img(unit)
        "File:#{unit['WikiName']} Face FC.webp"
      end

      def image_url_for_icon_chosen(unit)
        chosen = all_chosen_heroes_by_pagename[unit['Page']]
        element = chosen['ChosenEffect']
        "File:Chosen Effect #{element}.png"
      end

      def image_url_for_icon_legendary(unit)
        legend = all_legendary_heroes_by_pagename[unit['Page']]
        element = legend['LegendaryEffect']
        "File:Legendary Effect #{element}.png"
      end

      def image_url_for_icon_mythic(unit)
        mythic = all_mythic_heroes_by_pagename[unit['Page']]
        element = mythic['MythicEffect']
        suffix =
          if mythic['MythicEffect3'] != 'None'
            ' 03'
          elsif mythic['MythicEffect2'] != 'None'
            ' 02'
          else
            ''
          end
        "File:Mythic Effect #{element}#{suffix}.png"
      end

      def skill_icon(skill)
        "File:#{skill['Icon']}"
      end
    end
  end
end
