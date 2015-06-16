require 'automan'
require 'logger'

ENV['MAX_SNAPSHOTS'] = "50"

describe Automan::RDS::Snapshot do
  it { is_expected.to respond_to :rds }
  it { is_expected.to respond_to :create }
  it { is_expected.to respond_to :delete }
  it { is_expected.to respond_to :prune }
  it { is_expected.to respond_to :latest }
  it { is_expected.to respond_to :default_snapshot_name }

  describe '#default_snapshot_name' do
    subject() do
      AWS.stub!
      s = Automan::RDS::Snapshot.new
      s.logger = Logger.new('/dev/null')
      allow(s).to receive(:db_environment).and_return('dev1')
      s
    end

    it "never returns nil" do
      expect(subject.default_snapshot_name('somedb')).to_not be_nil
    end

    it "returns environment dash time string" do
      name = subject.default_snapshot_name('somedb')
      expect(name).to match /^dev1-(\d{4})-(\d{2})-(\d{2})T(\d{2})-(\d{2})/
    end

  end

  describe '#create' do
    subject() do
      AWS.stub!
      s = Automan::RDS::Snapshot.new
      s.logger = Logger.new('/dev/null')
      s
    end

    it "raises error if could not find database" do
      allow(subject).to receive(:find_db).and_return(nil)
      expect {
        subject.create
      }.to raise_error Automan::RDS::DatabaseDoesNotExistError
    end

    it "raises error if RDS says database does not exist" do
      db = double(:db)
      allow(db).to receive(:exists?).and_return(false)
      allow(subject).to receive(:find_db).and_return(db)

      expect {
        subject.create
      }.to raise_error Automan::RDS::DatabaseDoesNotExistError
    end

  end

  describe '#tagged_can_prune?' do
    subject() do
      AWS.stub!
      s = Automan::RDS::Snapshot.new
      s.logger = Logger.new('/dev/null')
      allow(s).to receive(:snapshot_arn)
      s
    end

    it 'returns true if snapshot is tagged with CanPrune=yes' do
      allow(subject).to receive(:tags).and_return( {'CanPrune' => 'yes'} )
      expect(subject.tagged_can_prune?( double() )).to be_truthy
    end

    it 'returns false if snapshot is missing CanPrune tag' do
      allow(subject).to receive(:tags).and_return( {} )
      expect(subject.tagged_can_prune?( double() )).to be_falsey
    end

    it 'returns false if snapshot is tagged with CanPrune=nil' do
      allow(subject).to receive(:tags).and_return( {'CanPrune' => nil} )
      expect(subject.tagged_can_prune?( double() )).to be_falsey
    end

    it 'returns false if snapshot is tagged with CanPrune=foo' do
      allow(subject).to receive(:tags).and_return( {'CanPrune' => 'foo'} )
      expect(subject.tagged_can_prune?( double() )).to be_falsey
    end
  end

  describe '#available?' do
    subject() do
      AWS.stub!
      s = Automan::RDS::Snapshot.new
      s.logger = Logger.new('/dev/null')
      s
    end

    it 'returns true if status is "available"' do
      snap = double(status: 'available')
      expect(subject.available?(snap)).to be_truthy
    end

    it 'returns false if status is foo' do
      snap = double(status: 'foo')
      expect(subject.available?(snap)).to be_falsey
    end
  end

  describe '#manual?' do
    let(:snap) { double }
    subject() do
      AWS.stub!
      s = Automan::RDS::Snapshot.new
      s.logger = Logger.new('/dev/null')
      s
    end

    it 'returns true if type is "manual"' do
      allow(snap).to receive(:snapshot_type).and_return('manual')
      expect(subject.manual?(snap)).to be_truthy
    end

    it 'returns false if type is foo' do
      allow(snap).to receive(:snapshot_type).and_return('foo')
      expect(subject.manual?(snap)).to be_falsey
    end
  end

  describe '#prunable_snapshots' do
    let(:snap) { double }
    subject() do
      AWS.stub!
      s = Automan::RDS::Snapshot.new
      s.logger = Logger.new('/dev/null')
      allow(s).to receive(:get_all_snapshots).and_return( [ snap ] )
      s
    end

    it 'includes snapshots which can be pruned' do
      allow(subject).to receive(:can_prune?).and_return(true)
      expect(subject.prunable_snapshots).to include(snap)
    end

    it 'excludes snapshots which should not be pruned' do
      allow(subject).to receive(:can_prune?).and_return(false)
      expect(subject.prunable_snapshots).to_not include(snap)
    end
  end
end