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
      @data_html_path = 'game8/html'
      @data_json_path = 'game8/json'
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
      page_ids.each do |kind, page_id|
        file_name = "#{page_id}.#{kind}"
        html_path = "#{data_html_path}/index/#{file_name}.html"
        if file_exist?(html_path)
          logger.warn "-- skipping fetch because file exists : #{file_name}"
          html = file_read(html_path)
        else
          logger.warn "-- fetching : #{page_id} - #{kind}"
          response = HTTP.get(game8_url(page_id))
          html = response.body.to_s
          file_write(html_path, html)
        end

        json_path = "#{data_json_path}/index/#{file_name}.json"
        list =
          if file_exist?(json_path) && !force_extraction
            logger.info "-- skipping extract because file exists : #{json_path}"
            JSON.parse(file_read(json_path))
          else
            logger.info "-- extracting : #{page_id} - #{kind}"
            json =
              begin
                extract_list(kind, html)
              rescue StandardError => e
                logger.error "---- error in extraction : #{e.message}"
                errors[:extract_list] << {
                  kind:,
                  page_id:,
                  url: game8_url(page_id),
                  class: e.class.name,
                  error: e.message,
                  backtrace: e.backtrace,
                }
                next
              end
            file_write(json_path, JSON.pretty_generate(json))
            json
          end
        ids = list.map { |item| item['game8_id'] }
        list += (missing_page_ids[kind] - ids).map { |id| { 'game8_id' => id } } if missing_page_ids[kind]

        list.each do |item|
          html_path = page_html_key(kind, item['game8_id'])
          if file_exist?(html_path)
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
          file_write(html_path, html)
        end
      end

      nil
    end

    def export_everything
      page_ids.each do |kind, page_id|
        final_file_name = "#{data_json_path}/detailed/#{kind}.json"
        if file_exist?(final_file_name) && !force_extraction
          logger.info "-- skipping export because file exists : #{final_file_name}"

          items = JSON.parse(file_read(final_file_name))
          case kind
          when self.class::KIND_UNIT
            @all_units += items
          else
            @all_skills += items
          end

          next
        end

        file_name = "#{page_id}.#{kind}"
        json_path = "#{data_json_path}/index/#{file_name}.json"
        next unless file_exist?(json_path)

        list = JSON.parse(file_read(json_path))
        ids = list.map { |item| item['game8_id'] }
        list += (missing_page_ids[kind] - ids).map { |id| { 'game8_id' => id } } if missing_page_ids[kind]

        items = list.map do |item|
          html_path = page_html_key(kind, item['game8_id'])
          unless file_exist?(html_path)
            logger.warn "-- skipping extract because file does not exist : #{html_path}"
            next
          end

          html = file_read(html_path)

          json_path = page_json_key(kind, item['game8_id'])
          if file_exist?(json_path) && !force_extraction
            JSON.parse(file_read(json_path))
          else
            logger.info "-- extracting : #{kind} - #{item['game8_id']} - #{item['game8_name']}"
            @current_item = item['game8_id']
            json =
              begin
                extract_item(kind, html, item)
              rescue StandardError => e
                logger.error "---- error in extraction : #{e.message}"
                errors[:extract_item] << {
                  kind:,
                  page_id: item['game8_id'],
                  url: game8_url(item['game8_id']),
                  class: e.class.name,
                  error: e.message,
                  backtrace: e.backtrace,
                }
                next
              end
            file_write(json_path, JSON.pretty_generate(json))
            json
          end
        end.compact

        logger.info "-- exporting to : #{final_file_name}"
        file_write(final_file_name, JSON.pretty_generate(items))

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
      delete_files_in("#{data_html_path}/index")
      delete_files_in("#{data_json_path}/index")
      delete_files_in("#{data_json_path}/detailed")

      nil
    end

    def reset_html_files
      delete_files_in(data_html_path)

      nil
    end

    def reset_json_files
      delete_files_in(data_json_path)

      nil
    end

    def page_html_key(kind, page_id)
      "#{data_html_path}/#{kind}/#{page_id}.html"
    end

    def page_json_key(kind, page_id)
      "#{data_json_path}/#{kind}/#{page_id}.json"
    end

    def delete_page_html_file(kind, page_id)
      log_and_file_delete(page_html_key(kind, page_id))
    end

    def delete_page_json_file(kind, page_id)
      log_and_file_delete(page_json_key(kind, page_id))
    end

    def delete_page_files(kind, page_id)
      delete_page_html_file(kind, page_id)
      delete_page_json_file(kind, page_id)
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
