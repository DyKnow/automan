require 'automan'
require 'logger'
require 'wait'

module Automan
  class Base
    class << self
      attr_accessor :option_names
    end

    attr_accessor :logger, :wait

    include Automan::Mixins::AwsCaller

    def initialize(options={})
      $stdout.sync = true
      @logger = Logger.new(STDOUT)

      if !options.nil?
        options.each_pair do |k,v|
          accessor = (k.to_s + '=').to_sym
          send(accessor, v) if respond_to? accessor
        end
      end

      aws_options = {}
      if options[:log_aws]
        aws_options[:logger] = @logger
      end
      configure_aws(aws_options)
    end

    def self.add_option(*args)
      args.each do |arg|
        self.class_eval("def #{arg};@#{arg};end")
        self.class_eval("def #{arg}=(val);@#{arg}=val;end")
        if self.option_names.nil?
          self.option_names = []
        end
        self.option_names << arg
      end
    end

    def log_options
      biggest_opt_name_length = self.class.option_names.max_by(&:length).length
      message = "called with:\n"
      self.class.option_names.each do |opt|
        opt_name = opt.to_s.concat(':').ljust(biggest_opt_name_length)
        message += "#{opt_name} #{send(opt)}\n"
      end
      logger.info message
    end

    def wait_until(raise_on_fail=nil, &block)
      begin
        wait.until do
          yield
        end
      rescue Wait::ResultInvalid => e
        if raise_on_fail.nil?
          raise e
        else
          raise raise_on_fail
        end
      end
    end
  end
end