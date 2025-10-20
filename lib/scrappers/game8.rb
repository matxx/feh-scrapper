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
      :now,
      :logger,
      :errors,
      :all_units,
      :all_skills,
      :current_item,
      :s3_files,
    )

    def initialize(level: Logger::ERROR)
      @data_html_path = 'game8/html'
      @data_json_path = 'game8/json'

      @now = Time.now
      @logger = Logger.new($stdout)
      logger.level = level

      boot
      setup_s3

      super
    end

    def reset!
      boot
    end

    def handle_everything
      log_and_launch(:list_existing_files)
      log_and_launch(:fetch_everything)
      log_and_launch(:export_everything)

      nil
    end

    def list_existing_files
      [data_html_path, data_json_path].each do |prefix|
        s3_files_in(prefix).each do |obj|
          s3_files << obj.key
        end
      end
    end

    def file_exist?(path)
      s3_files.include?(path)
    end

    def file_write(file_path, string)
      s3_files << file_path
      super
    end

    def file_delete(file_path)
      s3_files.delete file_path
      super
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
          if file_exist?(json_path)
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
          if item['game8_id'].nil?
            logger.warn "-- skipping fetch because no page ID : #{kind} - #{item['game8_name']}"
            errors[:missing_page_id] << {
              kind:,
              item:,
            }
            next
          end

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
      data_by_page_id = {}

      page_ids.each do |kind, page_id|
        final_file_name = "#{data_json_path}/detailed/#{kind}.json"
        if file_exist?(final_file_name)
          logger.info "-- file exists, retrieving previously extracted pages : #{final_file_name}"

          JSON.parse(file_read(final_file_name)).each do |item|
            data_by_page_id[item['game8_id']] = item
          end
        end

        file_name = "#{page_id}.#{kind}"
        json_path = "#{data_json_path}/index/#{file_name}.json"
        unless file_exist?(json_path)
          errors[:missing_index_file] << json_path
          logger.error "-- extract failed because file does not exist : #{json_path}"
          next
        end

        list = JSON.parse(file_read(json_path))
        ids = list.map { |item| item['game8_id'] }
        list += (missing_page_ids[kind] - ids).map { |id| { 'game8_id' => id } } if missing_page_ids[kind]

        items = list.map do |item|
          if item['game8_id'].nil?
            logger.warn "-- skipping extract because no page ID : #{kind} - #{item['game8_name']}"
            next
          end

          suffix = "#{kind} - #{item['game8_id']} - #{item['game8_name']}"

          if data_by_page_id[item['game8_id']]
            logger.info "-- skipping extract because already extracted : #{suffix}"
            next data_by_page_id[item['game8_id']]
          end

          html_path = page_html_key(kind, item['game8_id'])
          unless file_exist?(html_path)
            errors[:missing_page_file] << html_path
            logger.error "-- skipping extract because file does not exist : #{suffix} (#{html_path})"
            next
          end

          html = file_read(html_path)

          json_path = page_json_key(kind, item['game8_id'])
          if file_exist?(json_path)
            logger.info "-- skipping extract because already done : #{suffix}"
            JSON.parse(file_read(json_path))
          else
            logger.info "-- extracting : #{suffix}"
            @current_item = item['game8_id']
            json =
              begin
                extract_item(kind, html, item)
              rescue StandardError => e
                logger.error "---- error in extraction : #{e.message}"
                errors[:extract_item] << {
                  kind:,
                  page_id: item['game8_id'],
                  game8_name: item['game8_name'],
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

    def reset_detailed_files
      delete_files_in("#{data_json_path}/detailed")

      nil
    end

    def reset_index_files
      delete_files_in("#{data_html_path}/index")
      delete_files_in("#{data_json_path}/index")

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
      @s3_files = []
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
