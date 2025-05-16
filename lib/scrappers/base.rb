# frozen_string_literal: true

module Scrappers
  class Base
    EXPORT_DIRS = ['../feh-data/data'].freeze

    def initialize(*); end

    def log_and_launch(method)
      logger.error "[#{self.class}] #{method}"
      send(method)
    end
  end
end
