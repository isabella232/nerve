require 'spec_helper'
require 'nerve/reporter/zookeeper'

describe Nerve::Reporter::Zookeeper do
  let(:subject) { {
      'zk_hosts' => ['zkhost1', 'zkhost2'],
      'zk_path' => 'zk_path',
      'instance_id' => 'instance_id',
      'host' => 'host',
      'port' => 'port'
    }
  }

  let(:zk) { double("zk") }

  it 'actually constructs an instance' do
    expect(Nerve::Reporter::Zookeeper.new(subject).is_a?(Nerve::Reporter::Zookeeper)).to eql(true)
  end

  it 'deregisters service on exit' do
    allow(zk).to receive(:close!)
    allow(zk).to receive(:connected?).and_return(true)
    expect(zk).to receive(:exists?) { "zk_path" }.and_return(false)
    expect(zk).to receive(:mkdir_p) { "zk_path" }
    expect(zk).to receive(:create) { "full_path" }
    expect(zk).to receive(:delete).with("full_path", anything())

    allow(ZK).to receive(:new).and_return(zk)

    reporter = Nerve::Reporter::Zookeeper.new(subject)
    reporter.start
    reporter.report_up
    reporter.stop
  end

  context "when reporter is up" do
    before(:each) do
      allow(zk).to receive(:close!)
      allow(zk).to receive(:connected?).and_return(true)
      allow(zk).to receive(:exists?) { "zk_path" }.and_return(false)
      allow(zk).to receive(:mkdir_p) { "zk_path" }
      allow(zk).to receive(:create) { "full_path" }
      allow(zk).to receive(:set) { "full_path" }
      allow(zk).to receive(:delete).with("full_path", anything())
      allow(ZK).to receive(:new).and_return(zk)
      @reporter = Nerve::Reporter::Zookeeper.new(subject)
      @reporter.start
      @reporter.report_up
    end

    after(:each) do
      # reset the class variable to avoid mock object zk leak
      Nerve::Reporter::Zookeeper.class_variable_set(:@@zk_pool, {})
      Nerve::Reporter::Zookeeper.class_variable_set(:@@zk_pool_count, {})
    end

    it "returns true on report_up" do
      expect(@reporter.report_up).to be true
    end

    it "returns true on report_down" do
      expect(@reporter.report_down).to be true
    end

    it "returns true on ping?" do
      expect(zk).to receive(:exists?) { "zk_path" }.and_return(true)
      expect(@reporter.ping?).to be true
    end

    context "when zk.connected? started to return false" do
      before(:each) do
        # this condition is triggered if connection has been lost for a while (a few sec)
        expect(zk).to receive(:connected?).and_return(false)
      end

      it 'returns false on ping?' do
        expect(zk).not_to receive(:exists?)
        expect(@reporter.ping?).to be false
      end

      it 'returns false on report_up without zk operation' do
        expect(zk).not_to receive(:set)
        expect(@reporter.report_up).to be false
      end

      it 'returns false on report_up without zk operation' do
        expect(zk).not_to receive(:delete)
        expect(@reporter.report_down).to be false
      end
    end

    context "when there is a short disconnection" do
      before(:each) do
        # this condition is triggered if connection is shortly interrupted
        # so connected? still return true
        expect(zk).to receive(:exists?).and_raise(ZK::Exceptions::OperationTimeOut)
      end

      it 'returns false on ping?' do
        expect(@reporter.ping?).to be false
      end

      it 'swallows zk connetion errors and returns false on report_up' do
        expect(@reporter.report_up).to be false
      end

      it 'swallows zk connetion errors and returns false on report_down' do
        expect(@reporter.report_down).to be false
      end
    end

    context "when there is other ZK errors" do
      before(:each) do
        # this condition is triggered if connection is shortly interrupted
        # so connected? still return true
        expect(zk).to receive(:exists?).and_raise(ZK::Exceptions::SessionExpired)
      end

      it 'raises zk non-connection error on ping?' do
        expect {@reporter.ping?}.to raise_error(ZK::Exceptions::SessionExpired)
      end

      it 'raises zk non-connetion errors on report_up' do
        expect {@reporter.report_up}.to raise_error(ZK::Exceptions::SessionExpired)
      end

      it 'raises zk non-connetion errors on report_down' do
        expect {@reporter.report_down}.to raise_error(ZK::Exceptions::SessionExpired)
      end
    end
  end
end

