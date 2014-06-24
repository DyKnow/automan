module Automat::Mixins
  module Utils

    S3_PROTO = 's3://'

    def looks_like_s3_path?(path)
      path.start_with? S3_PROTO
    end

    def parse_s3_path(path)

      if !looks_like_s3_path? path
        raise ArgumentError, "s3 path must start with '#{S3_PROTO}'"
      end

      rel_path = path[S3_PROTO.length..-1]
      bucket = rel_path.split('/').first
      key = rel_path.split('/')[1..-1].join('/')

      return bucket, key

    end

    def region_from_az(availability_zone)
      availability_zone[0..-2]
    end

    class ::String
      def underscore
        self.gsub(/::/, '/').
        gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
        gsub(/([a-z\d])([A-Z])/,'\1_\2').
        tr("-", "_").
        downcase
      end
    end
  end
end
