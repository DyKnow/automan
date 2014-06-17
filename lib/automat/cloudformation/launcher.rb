require 'automat/mixins/aws_caller'
require 'logger'

# TODO: add timeout

module Automat::Cloudformation
  class Launcher
    attr_accessor :name,
                  :template,
                  :disable_rollback,
                  :enable_iam,
                  :enable_update,
                  :parameters,
                  :logger

    include Automat::Mixins::AwsCaller

    def initialize(options=nil)
      @logger = Logger.new(STDOUT)
      @log_aws_calls = false

      if !options.nil?
        @template         = options[:template]
        @name             = options[:name]
        @disable_rollback = options[:disable_rollback]
        @enable_update    = options[:enable_update]
        @parameters       = options[:parameters]
      end
    end

    def log_options
      message =  "called with:\n"
      message += "name:             #{name}\n"
      message += "template:         #{template}\n"
      message += "disable_rollback: #{disable_rollback}\n"
      message += "enable_update:    #{enable_update}\n"
      message += "parameters:       #{parameters.inspect}\n"
      logger.info message
    end

    def template_handle(template_path)
      if template_path.start_with? 's3://'
        path = template_path[5..-1]
        bucket = path.split('/').first
        key = path.split('/')[1..-1].join('/')
        return s3.buckets[bucket].objects[key]
      else
        return File.read(template_path)
      end
    end

    def parse_template_parameters
      cfn.validate_template( template_handle(template) )
    end

    def validate_parameters
      if parameters.nil?
        raise MissingParametersError, "there are no parameters!"
      end

      template_params_hash = parse_template_parameters

      if template_params_hash.has_key? :code
        mesg = template_params_hash[:message]
        raise BadTemplateError, "template did not validate: #{mesg}"
      end

      # make sure any template parameters w/o a default are specified
      template_params = template_params_hash[:parameters]
      required_params = template_params.select { |x| !x.has_key? :default_value}
      required_params.each do |rp|
        unless parameters.has_key? rp[:parameter_key]
          raise MissingParametersError, "required parameter #{rp[:parameter_key]} was not specified"
        end
      end

      # add iam capabilities if needed
      if template_params_hash.has_key?(:capabilities) &&
        template_params_hash[:capabilities].include?('CAPABILITY_IAM')
        self.enable_iam = true
      end

    end

    def stack_exists?
      cfn.stacks[name].exists?
    end

    def launch
      opts = {
        parameters: parameters
      }
      opts[:capabilities] = ['CAPABILITY_IAM'] if enable_iam
      opts[:disable_rollback] = disable_rollback

      logger.info "launching stack #{name}"
      cfn.stacks.create name, template_handle(template), opts
    end

    def update
      opts = {
        template: template_handle(template),
        parameters: parameters
      }
      opts[:capabilities] = ['CAPABILITY_IAM'] if enable_iam

      logger.info "updating stack #{name}"

      # if cfn determines that no updates are to be performed,
      # it raises a ValidationError
      begin
        cfn.stacks[name].update( opts )
      rescue AWS::CloudFormation::Errors::ValidationError => e
        if e.message != "No updates are to be performed."
          raise e
        else
          logger.info e.message
        end
      end
    end

    def launch_or_update
      log_options

      validate_parameters

      if stack_exists?

        logger.info "stack #{name} exists"
        if enable_update == true
          update
        else
          raise StackExistsError, "stack #{name} already exists"
        end

      else
        launch
      end

    end

    def terminate
      log_options
      logger.info "terminating stack #{name}"
      cfn.stacks[name].delete
    end

    def asg_from_stack
      resources = cfn.stacks[name].resources
      asgs = resources.select {|i| i.resource_type == "AWS::AutoScaling::AutoScalingGroup"}
      if asgs.nil? || asgs.empty?
        return nil
      end
      asg_id = asgs.first.physical_resource_id
      as.groups[asg_id]
    end

    # terminate all running instances in the ASG so that new
    # machines with the latest build will be started
    def replace_instances
      log_options
      logger.info "replacing all auto-scaling instances in #{name}"
      asg = asg_from_stack
      asg.ec2_instances.each do |i|
        logger.info "terminating instance #{i.id}"
        i.terminate
      end
    end

  end

  class MissingParametersError < StandardError
  end

  class BadTemplateError < StandardError
  end

  class StackExistsError < StandardError
  end
end