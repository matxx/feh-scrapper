# frozen_string_literal: true

require 'open-uri'

module Scrappers
  class S3 < Base
    attr_reader :now, :logger, :all_seals_by_id, :all_skills_by_id

    COMMIT = 'b9553b1da07d82c0e7ef98d6c47d012af50bf044'
    DIR = "https://data.feh-peeler.com/commits/#{COMMIT}".freeze

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
      log_and_launch(:fetch_everything)

      nil
    end

    def fetch_everything
      log_and_launch(:fetch_seals)
      log_and_launch(:fetch_skills)

      nil
    end

    def fetch_seals
      @all_seals = fetch_json("#{DIR}/seals.json")
      @all_seals_by_id = @all_seals.index_by { |s| s['id'] }

      nil
    end

    def fetch_skills
      @all_skills = fetch_json("#{DIR}/skills.json")
      @all_skills_by_id = @all_skills.index_by { |s| s['id'] }

      nil
    end

    def inspect
      "<#{self.class} @now=#{now}>"
    end

    private

    def fetch_json(url)
      raw = URI.parse(url).open.read
      JSON.parse(raw)
    end

    def boot
      @all_seals = nil
      @all_seals_by_id = nil
      @all_skills = nil
      @all_skills_by_id = nil
    end
  end
end
