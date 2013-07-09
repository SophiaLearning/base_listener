require 'spec_helper'
module TestWorkers
  class ThisWorker
    attr_reader :message
    def initialize(message)
      @message = message
    end
  end
end

describe BaseListener::Listener do
  let(:listener)   { BaseListener::Listener.new 'test-appid' }
  let(:connection) { MockBunny.new }
  let(:payload)    { { worker: 'TestWorkers::ThisWorker', message: 'message' } }

  before { Bunny.stub new: connection }

  describe 'initialize' do
    context 'sets' do
      it 'appid' do
        listener.appid.should == 'test-appid'
      end
    end
  end

  describe '#connection' do
    it 'initialize bunny with correct params' do
      Bunny.should_receive(:new).with BaseListener::Config.connection_params
      listener.__send__ :connection
    end

    it 'starts connection' do
      connection.should_receive(:start)
      listener.__send__ :connection
    end

    it 'writes connection to @connection' do
      listener.__send__ :connection
      listener.instance_variable_get('@connection').should == connection
    end
  end

  describe '#channel' do
    it 'creates new channel' do
      connection.should_receive :create_channel
      listener.__send__ :channel
    end

    it 'writes it to @channel' do
      listener.__send__ :channel
      listener.instance_variable_get('@channel').should == connection.create_channel
    end
  end

  describe '#exchange' do
    it 'creates direct exchange' do
      listener.__send__(:channel).should_receive(:direct).with 'exchange', durable: true
      listener.__send__ :exchange
    end

    it 'writes it to @exchange' do
      listener.__send__ :exchange
      listener.instance_variable_get('@exchange').should == 'direct exchange'
    end
  end

  describe 'interface' do
    BaseListener::Listener::INTERFACE.each do |name|
      it name do
        expect { listener.__send__(name) }.to raise_error(BaseListener::MustBeDefinedInChildClass)
      end
    end
  end

  describe '#requeue_if_needed' do
    it 'requeues given payload if block returns false' do
      listener.should_receive(:requeue).with 'payload'
      listener.__send__(:requeue_if_needed, 'payload') { false }
    end

    it 'doesnt requeue if block returns true' do
      listener.should_not_receive :requeue
      listener.__send__(:requeue_if_needed, 'payload') { true }
    end
  end

  describe '#worker_for' do
    it 'initialize correct worker' do
      listener.__send__(:worker_for, payload).should be_a(TestWorkers::ThisWorker)
    end

    it 'suply it with message' do
      listener.__send__(:worker_for, payload).message.should == payload[:message]
    end
  end
end
