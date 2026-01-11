# frozen_string_literal: true

module Scrappers
  module Fandoms
    module Images
      attr_reader :all_images_by_pagename

      # possible errors when retrieving too much images at a time :
      # - with limit 500 :
      # `unexpected HTTP response (414) (MediawikiApi::HttpError)`
      # - with limit 100 :
      # `Too many values supplied for parameter "titles". The limit is 50. (toomanyvalues) (MediawikiApi::ApiError)`
      MAX_TITLES_SIZE = 50

      def reset_all_images_by_pagename!
        @all_images_by_pagename = nil
      end

      def scrap_all_images
        return if all_images_by_pagename

        @all_images_by_pagename = {}
        pages_to_retrieve = []

        # unit portraits
        pages_to_retrieve += all_units.flat_map do |unit|
          list = [
            unit_img_thumbnail(unit),
            unit_img_art_a(unit),
            unit_img_art_b(unit),
            unit_img_art_c(unit),
            unit_img_art_d(unit),
          ]
          next list unless unit['Properties']&.include?('resplendent')

          list + [
            unit_img_art_resp_a(unit),
            unit_img_art_resp_b(unit),
            unit_img_art_resp_c(unit),
            unit_img_art_resp_d(unit),
          ]
        end

        # chosen unit icons
        pages_to_retrieve +=
          ['Fire', 'Water', 'Wind', 'Earth']
          .map { |element| "File:Chosen Effect #{element}.png" }

        # legendary unit icons
        pages_to_retrieve +=
          ['Fire', 'Water', 'Wind', 'Earth']
          .map { |element| "File:Legendary Effect #{element}.png" }

        # mythic unit icons
        pages_to_retrieve +=
          ['Light', 'Dark', 'Astra', 'Anima']
          .product(['', ' 02', ' 03'])
          .flat_map { |element, suffix| "File:Mythic Effect #{element}#{suffix}.png" }

        # skill icons
        pages_to_retrieve += all_skills.map { |skill| skill_icon(skill) }

        # seal icons
        pages_to_retrieve += all_seals.map { |skill| skill_icon(skill) }

        retrieve_images(pages_to_retrieve.uniq)

        nil
      end

      def fill_units_with_images
        all_units.each do |unit|
          unit[:image_url_for_portrait] = all_images_by_pagename[unit_img_thumbnail(unit)]

          unit[:image_url_for_art_a] = all_images_by_pagename[unit_img_art_a(unit)]
          unit[:image_url_for_art_b] = all_images_by_pagename[unit_img_art_b(unit)]
          unit[:image_url_for_art_c] = all_images_by_pagename[unit_img_art_c(unit)]
          unit[:image_url_for_art_d] = all_images_by_pagename[unit_img_art_d(unit)]
          if unit[:properties].include?('resplendent')
            unit[:image_url_for_art_resp_a] = all_images_by_pagename[unit_img_art_resp_a(unit)]
            unit[:image_url_for_art_resp_b] = all_images_by_pagename[unit_img_art_resp_b(unit)]
            unit[:image_url_for_art_resp_c] = all_images_by_pagename[unit_img_art_resp_c(unit)]
            unit[:image_url_for_art_resp_d] = all_images_by_pagename[unit_img_art_resp_d(unit)]
          end

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

      def retrieve_images(pages_to_retrieve, limit = MAX_TITLES_SIZE)
        total = pages_to_retrieve.size
        offset = 0
        loop do
          titles = pages_to_retrieve[offset..offset + limit - 1]
          break if titles.nil? || titles.empty?

          response =
            begin
              logger.warn %{-- querying images (total: #{total}, with limit: #{limit}, offset: #{offset})}
              client.query(
                format: :json,
                prop: :imageinfo,
                iiprop: :url,
                titles:,
              )
            rescue MediawikiApi::ApiError => e
              raise e unless e.message.include?('ratelimited')

              logger.error '--- rate limit exceeded : going to sleep'
              sleep 5
              retry
            end

          response.data['pages'].each_value do |data|
            next if data['imageinfo'].nil?

            all_images_by_pagename[data['title']] =
              data['imageinfo'][0]['url'].gsub(%r{https://static\.}, 'https://vignette.')
          end

          offset += limit
        end

        nil
      end

      def unit_img_thumbnail(unit)
        "File:#{unit['WikiName']} Face FC.webp"
      end

      def unit_img_art_a(unit)
        "File:#{unit['WikiName']} Face.webp"
      end

      def unit_img_art_b(unit)
        "File:#{unit['WikiName']} BtlFace.webp"
      end

      def unit_img_art_c(unit)
        "File:#{unit['WikiName']} BtlFace C.webp"
      end

      def unit_img_art_d(unit)
        "File:#{unit['WikiName']} BtlFace D.webp"
      end

      def unit_img_art_resp_a(unit)
        "File:#{unit['WikiName']} Resplendent Face.webp"
      end

      def unit_img_art_resp_b(unit)
        "File:#{unit['WikiName']} Resplendent BtlFace.webp"
      end

      def unit_img_art_resp_c(unit)
        "File:#{unit['WikiName']} Resplendent BtlFace C.webp"
      end

      def unit_img_art_resp_d(unit)
        "File:#{unit['WikiName']} Resplendent BtlFace D.webp"
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
