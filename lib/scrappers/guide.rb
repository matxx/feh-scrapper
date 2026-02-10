# frozen_string_literal: true

require 'uri'
require 'open-uri'
require 'nokogiri'

module Scrappers
  class Guide < Base
    attr_reader(
      :now,
      :errors,
      :logger,

      :all_units,
      :all_units_by_id,
      :all_units_by_names,
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
      log_and_launch(:scrap_units)

      nil
    end

    def scrap_units
      return if all_units

      page = 'https://guide.fire-emblem-heroes.com/en-US/category/character/'
      response = HTTP.get(page)
      html = response.body.to_s

      # MONKEY PATCH: all <li> are wrongfully self closed...
      fixed = html.gsub(%r{(<li [^/>]+)/>}, '\1>')

      dom = Nokogiri::HTML.parse(fixed)
      @all_units = []
      dom.css('.character_ul li').each do |li|
        link = li.at('a').attr('href')

        all_units << {
          id: link.split('/').last,
          name: li.at('.character_name').text.strip,
          title: li.at('.character_nick').text.strip,
        }
      end

      @all_units_by_id = all_units.index_by { |x| x[:id].split('-').first }
      @all_units_by_names = all_units.index_by { |x| [x[:name], x[:title]] }

      units_with_same_ids = all_units.group_by { |x| x[:id].split('-').first }.select { |_, v| v.size > 1 }
      errors[:units_with_same_ids] = units_with_same_ids.keys if units_with_same_ids.any?

      units_with_same_names = all_units.group_by { |x| [x[:name], x[:title]] }.select { |_, v| v.size > 1 }
      errors[:units_with_same_names] = units_with_same_names.keys if units_with_same_names.any?

      nil
    end

    def reset_all_units!
      @all_units = nil
      @all_units_by_id = nil
      @all_units_by_names = nil
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
