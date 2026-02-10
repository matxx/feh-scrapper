# frozen_string_literal: true

require 'uri'
require 'open-uri'
require 'nokogiri'

module Scrappers
  class Pages < Base
    attr_reader(
      :now,
      :errors,
      :logger,

      :all_guides,
      :all_guides_by_names,
      :all_respls,
      :all_respls_by_names,
    )

    def initialize(level: Logger::ERROR)
      @now = Time.now

      @logger = Logger.new($stdout)
      logger.level = level

      boot

      super
    end

    def reset!
      boot
    end

    def handle_everything
      log_and_launch(:scrap_everything)

      nil
    end

    def scrap_everything
      log_and_launch(:scrap_guides)
      log_and_launch(:scrap_respls)

      nil
    end

    def scrap_guides
      return if all_guides

      page = 'https://guide.fire-emblem-heroes.com/en-US/category/character/'
      response = HTTP.get(page)
      html = response.body.to_s

      # MONKEY PATCH: all <li> are wrongfully self closed...
      fixed = html.gsub(%r{(<li [^/>]+)/>}, '\1>')

      dom = Nokogiri::HTML.parse(fixed)
      @all_guides = []
      dom.css('.character_ul li').each do |li|
        link = li.at('a').attr('href')

        all_guides << {
          id: link.split('/').last,
          name: li.at('.character_name').text.strip,
          title: li.at('.character_nick').text.strip,
        }
      end

      @all_guides_by_names = all_guides.index_by { |x| [x[:name], x[:title]] }

      guides_with_same_names = all_guides.group_by { |x| [x[:name], x[:title]] }.select { |_, v| v.size > 1 }
      errors[:guides_with_same_names] = guides_with_same_names.keys if guides_with_same_names.any?

      nil
    end

    def reset_all_guides!
      @all_guides = nil
      @all_guides_by_names = nil
    end

    def scrap_respls
      return if all_respls

      page = 'https://fehpass.fire-emblem-heroes.com/en-US/'
      response = HTTP.get(page)
      html = response.body.to_s
      dom = Nokogiri::HTML.parse(html)
      @all_respls = []
      (dom.css('.cahra_list li') + dom.css('section.next') + dom.css('section.new')).each do |li|
        link = li.at('a').attr('href')

        all_respls << {
          id: link.split('/').first,
          name:  li.at('.chara_txt > dd').text.strip,
          title: li.at('.chara_txt > dt').text.strip,
        }
      end

      @all_respls_by_names = all_respls.index_by { |x| [x[:name], x[:title]] }

      respls_with_same_names = all_respls.group_by { |x| [x[:name], x[:title]] }.select { |_, v| v.size > 1 }
      errors[:respls_with_same_names] = respls_with_same_names.keys if respls_with_same_names.any?

      nil
    end

    def reset_all_respls!
      @all_respls = nil
      @all_respls_by_names = nil
    end

    def inspect
      "<#{self.class} @now=#{now}>"
    end

    private

    def boot
      @errors = empty_errors
    end

    def empty_errors
      Hash.new { |h, k| h[k] = [] }
    end
  end
end
