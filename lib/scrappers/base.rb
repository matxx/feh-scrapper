# frozen_string_literal: true

module Scrappers
  class Base
    def initialize(*); end

    private

    def log_and_launch(method)
      logger.error "[#{self.class}] #{method}"
      send(method)
    end
  end
end
