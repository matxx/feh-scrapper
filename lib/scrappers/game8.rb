# frozen_string_literal: true

require 'http'
require 'nokogiri'

require 'scrappers/base'
require 'scrappers/game8s/skills'
require 'scrappers/game8s/units'
require 'scrappers/game8s/utils'

module Scrappers
  class Game8 < Base
    include Scrappers::Game8s::Skills
    include Scrappers::Game8s::Units
    include Scrappers::Game8s::Utils

    attr_reader(
      :data_html_path,
      :data_json_path,
      :force_extraction,
      :now,
      :logger,
      :errors,
      :all_units,
      :all_skills,
      :current_item,
    )

    def initialize(level: Logger::ERROR, force_extraction: false)
      ENV['DIR_DATA'] ||= 'data'
      @data_html_path = "#{ENV.fetch('DIR_DATA')}/game8/html"
      @data_json_path = "#{ENV.fetch('DIR_DATA')}/game8/json"
      @force_extraction = force_extraction

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
      log_and_launch(:fetch_everything)
      log_and_launch(:export_everything)

      nil
    end

    def fetch_everything
      FileUtils.mkdir_p data_html_path
      FileUtils.mkdir_p data_json_path

      page_ids.each do |kind, page_id|
        file_name = "#{page_id}.#{kind}"
        html_path = "#{data_html_path}/#{file_name}.html"
        if File.exist?(html_path)
          logger.warn "-- skipping fetch because file exists : #{file_name}"
          html = File.read(html_path)
        else
          logger.warn "-- fetching : #{page_id} - #{kind}"
          response = HTTP.get(game8_url(page_id))
          html = response.body.to_s
          File.write(html_path, html)
        end

        json_path = "#{data_json_path}/#{file_name}.json"
        list =
          if File.exist?(json_path) && !force_extraction
            logger.info "-- skipping extract because file exists : #{json_path}"
            JSON.parse(File.read(json_path))
          else
            logger.info "-- extracting : #{page_id} - #{kind}"
            json = extract_list(kind, html)
            File.write(json_path, JSON.pretty_generate(json))
            json
          end
        ids = list.map { |item| item['game8_id'] }
        list += (missing_page_ids[kind] - ids).map { |id| { 'game8_id' => id } } if missing_page_ids[kind]

        FileUtils.mkdir_p "#{data_html_path}/#{kind}"
        FileUtils.mkdir_p "#{data_json_path}/#{kind}"

        list.each do |item|
          html_path = "#{data_html_path}/#{kind}/#{item['game8_id']}.html"
          if File.exist?(html_path)
            logger.warn "-- skipping fetch because file exists : #{html_path}"
            next
          end

          logger.warn "-- fetching : #{kind} - #{item['game8_id']} - #{item['game8_name']}"
          response = HTTP.get(game8_url(item['game8_id']))
          # new units/skills
          # not yet released by game8
          if response.status.not_found?
            logger.warn "-- skipping save because unit/skill not released : #{html_path}"
            next
          end

          html = response.body.to_s
          File.write(html_path, html)
        end
      end

      nil
    end

    def export_everything
      FileUtils.mkdir_p "#{data_json_path}/detailed"

      page_ids.each do |kind, page_id|
        final_file_name = "#{data_json_path}/detailed/#{kind}.json"
        if File.exist?(final_file_name) && !force_extraction
          logger.info "-- skipping export because file exists : #{final_file_name}"

          items = JSON.parse(File.read(final_file_name))
          case kind
          when self.class::KIND_UNIT
            @all_units += items
          else
            @all_skills += items
          end

          next
        end

        file_name = "#{page_id}.#{kind}"
        json_path = "#{data_json_path}/#{file_name}.json"
        list = JSON.parse(File.read(json_path))
        ids = list.map { |item| item['game8_id'] }
        list += (missing_page_ids[kind] - ids).map { |id| { 'game8_id' => id } } if missing_page_ids[kind]

        items = list.map do |item|
          html_path = "#{data_html_path}/#{kind}/#{item['game8_id']}.html"
          unless File.exist?(html_path)
            logger.warn "-- skipping extract because file does not exist : #{html_path}"
            next
          end

          html = File.read(html_path)

          json_path = "#{data_json_path}/#{kind}/#{item['game8_id']}.json"
          if File.exist?(json_path) && !force_extraction
            JSON.parse(File.read(json_path))
          else
            logger.info "-- extracting : #{kind} - #{item['game8_id']} - #{item['game8_name']}"
            @current_item = item['game8_id']
            json = extract_item(kind, html, item)
            File.write(json_path, JSON.pretty_generate(json))
            json
          end
        end.compact

        logger.info "-- exporting to : #{final_file_name}"
        File.write(final_file_name, JSON.pretty_generate(items))

        case kind
        when self.class::KIND_UNIT
          @all_units += items
        else
          @all_skills += items
        end
      end

      nil
    end

    def inspect
      "<#{self.class} @now=#{now}>"
    end

    def reset_index_files
      Dir['data/game8/html/*.html'].each do |file|
        File.delete(file)
      end
      Dir['data/game8/json/*.json', 'data/game8/json/detailed/*.json'].each do |file|
        File.delete(file)
      end

      nil
    end

    def reset_json_files
      Dir['data/game8/json/**/*.json'].each do |file|
        File.delete(file)
      end

      nil
    end

    private

    def boot
      @errors = empty_errors
      @all_units = []
      @all_skills = []
      @page_ids = nil
      @current_item = nil
    end

    def empty_errors
      Hash.new { |h, k| h[k] = [] }
    end

    def page_ids
      @page_ids ||= PAGE_ID_UNITS.merge(PAGE_ID_SKILLS)
    end

    def missing_page_ids
      @missing_page_ids ||= PAGE_IDS_OF_NEW_UNITS.merge(PAGE_IDS_OF_NEW_SKILLS)
    end

    def raise_with_item(message)
      raise "[#{current_item}] #{message}"
    end
  end
end
