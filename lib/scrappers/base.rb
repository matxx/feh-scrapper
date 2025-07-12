# frozen_string_literal: true

require 'scrappers/utils/s3'

module Scrappers
  class Base
    include Scrappers::Utils::S3

    def initialize(*); end

    def log_and_launch(method)
      logger.error "[#{self.class}] #{method}"
      send(method)
    end

    def export_files(data)
      data.each do |filename, method|
        hash =
          case method
          when Hash
            method
          when Symbol
            send(method)
          when Proc
            method.call
          else
            raise "method not handled : #{method.class}"
          end

        string = JSON.pretty_generate(hash)
        file_write("exports/#{filename}", string)
      end

      nil
    end
  end
end
