# frozen_string_literal: true

require 'aws-sdk-s3'

module Scrappers
  module Utils
    module S3
      def setup_s3
        Aws.config[:region] = ENV.fetch('FEH_S3_REGION')
        Aws.config[:credentials] = Aws::Credentials.new(
          ENV.fetch('FEH_S3_ACCESS_KEY_ID'),
          ENV.fetch('FEH_S3_SECRET_ACCESS_KEY'),
        )
      end

      def s3_bucket
        @s3_bucket ||= Aws::S3::Bucket.new(ENV.fetch('FEH_S3_BUCKET_NAME'))
      end

      def s3_files_in(prefix, &)
        s3_bucket.objects(prefix:, &)
      end

      def s3_file(file_path)
        s3_bucket.object(file_path)
      end

      def file_exist?(file_path)
        s3_file(file_path).exists?
      end

      def file_delete(file_path)
        s3_file(file_path).delete
      end

      def file_read(file_path)
        s3_file(file_path).get.body.read
      end

      def file_write(file_path, string)
        content_type =
          case File.extname(file_path)
          when '.json'
            'application/json'
          when '.html'
            'text/html'
          else
            raise "extension not handled : #{File.extname(file_path)}"
          end

        s3_file(file_path).put(
          body: string,
          content_type:,
        )
      end

      def log_and_file_delete(file_path, message_prefix: '')
        logger.info "#{message_prefix}deleting file : #{file_path}"
        file_delete(file_path)
      end

      def delete_files_in(prefix)
        s3_files_in(prefix).each do |obj|
          log_and_file_delete(obj.key, message_prefix: '-- ')
        end
      end
    end
  end
end
