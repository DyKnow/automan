require 'automat/base'
require 'automat/s3/errors'
require 'automat/mixins/utils'

module Automat::S3
  class Downloader < Automat::Base
    add_option :localfile, :s3file

    include Automat::Mixins::Utils

    def download
      log_options

      logger.info "uploading #{localfile} to #{s3file}"

      bucket, key = parse_s3_path s3file

      File.open(localfile, 'wb') do |file|
        s3.buckets[bucket].objects[key].read do |chunk|
          file.write(chunk)
        end
      end

    end

  end
end