require 'spec_helper'

class ThatWorker
  attr_reader :message
  def initialize(message)
    @message = message
  end

  def perform
    true
  end
end

module TestWorkers
  class ThisWorker < ThatWorker
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
      listener.instance_variable_get('@exchange').should == connection.create_channel.direct
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

    it 'initialize correct worker when it not in namespace' do
      listener.__send__(:worker_for, payload.merge(worker: 'ThatWorker')).should be_a(ThatWorker)
    end

    it 'suply it with message' do
      listener.__send__(:worker_for, payload).message.should == payload[:message]
    end
  end

  describe '#max_requeue_tries' do
    it 'returns 3' do
      listener.__send__(:max_requeue_tries).should == 3
    end
  end

  describe 'requeue' do
    context 'wneh requeue first time' do
      it 'publish paylod to exchange with correct args' do
        listener.__send__(:exchange).should_receive(:publish).with do |p, hash|
          Marshal.load(p).should == payload.merge(requeue_tries: 1)
          hash.should == { routing_key: 'routing_keys.retry.test-appid', persisted: true }
        end

        listener.__send__ :requeue, payload
      end
    end

    context 'when requeue not first time' do
      context 'when requeue_tries is less or equeal to max_requeue_tries' do
        it 'publish paylod to exchange with correct args' do
          listener.__send__(:exchange).should_receive(:publish).with do |p, hash|
            Marshal.load(p).should == payload.merge(requeue_tries: 4)
            hash.should == { routing_key: 'routing_keys.retry.test-appid', persisted: true }
          end

          listener.__send__ :requeue, payload.merge(requeue_tries: 3)
        end
      end

      context 'when requeue_tries is more then max_requeue_tries' do
        it 'doesnt publish payload to exchange' do
          listener.__send__(:exchange).should_not_receive :publish
          listener.__send__ :requeue, payload.merge(requeue_tries: 4)
        end
      end
    end
  end

  describe '#subscribe!' do
    let(:queue) do
      q = connection.channel.queue
      q.payload = payload
      q
    end

    let(:routing_key) { 'routing_keys.test_key' }
    before { listener.stub queue: queue, routing_key: routing_key }
    after  { listener.subscribe! }

    it 'binds to exchange with correct routing key' do
      queue.should_receive(:bind).with(connection.channel.exchange, routing_key: routing_key).and_return(queue)
    end

    it 'subscribes to queue with correct params' do
      queue.should_receive(:subscribe).with block: true
    end

    it 'calls for worker_for' do
      listener.should_receive(:worker_for).with(payload).and_return TestWorkers::ThisWorker.new(payload[:message])
    end

    it 'makes worker to perfom message' do
      TestWorkers::ThisWorker.any_instance.should_receive(:perform).and_return true
    end

    it 'requeues payload if worker returns false' do
      TestWorkers::ThisWorker.any_instance.should_receive(:perform).and_return false
      listener.should_receive(:requeue).with payload
    end
  end
end
