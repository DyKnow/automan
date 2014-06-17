require "automat"

describe Automat::Beanstalk::Deployer do

  it { should respond_to :name }
  it { should respond_to :version_label }
  it { should respond_to :bucket }
  it { should respond_to :environment }
  it { should respond_to :configuration_template }
  it { should respond_to :logger }
  it { should respond_to :eb }
  it { should respond_to :s3 }
  it { should respond_to :log_aws_calls }
  it { should respond_to :deploy }
  it { should respond_to :terminate }

  # Constraint: Must be from 4 to 23 characters in length.
  # The name can contain only letters, numbers, and hyphens.
  # It cannot start or end with a hyphen.
  describe '#eb_environment_name' do
    subject(:bd) { Automat::Beanstalk::Deployer.new }

    it "is at least 4 characters" do
      bd.name = "a"
      bd.environment = "a"
      bd.eb_environment_name.length.should be >= 4
    end

    it "is no more than 23 characters" do
      bd.name = "a" * 23
      bd.environment = "dev"
      bd.eb_environment_name.length.should be <= 23
    end

    it "contains only letters, numbers, and hyphens" do
      bd.name = '@#$%^foo_bar!$%&&E.'
      bd.environment = 'prod.baz'
      bd.eb_environment_name.should match(/[a-z0-9-]+/)
    end

    it "cannot start or end with a hyphen" do
      bd.name = '--foo'
      bd.environment = 'bar--'
      bd.eb_environment_name.should match(/^[^-].*[^-]$/)
    end

    it "is still at least 4 characters even after removing restricted strings" do
      bd.name = '--f'
      bd.environment = '-'
      bd.eb_environment_name.length.should be >= 4
    end
  end

  describe '#version_exists?' do
    subject(:bd) do
      AWS.stub!
      bd = Automat::Beanstalk::Deployer.new
      bd.eb = AWS::ElasticBeanstalk::Client.new
      bd.name = 'foo'
      bd.version_label = 'v4'
      bd.log_aws_calls = false
      bd.logger = Logger.new('/dev/null')
      bd
    end

    it "is true when version exists in response" do
      resp = bd.eb.stub_for :describe_application_versions
      resp.data[:application_versions] = [
        {application_name: bd.name, version_label: bd.version_label}
      ]
      bd.version_exists?.should be_true
    end

    it "is false when version is not in response" do
      resp = bd.eb.stub_for :describe_application_versions
      resp.data[:application_versions] = [
        {application_name: '', version_label: ''}
      ]
      bd.version_exists?.should be_false
    end
  end
end

