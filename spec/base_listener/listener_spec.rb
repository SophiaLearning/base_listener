require 'spec_helper'

class ThatWorker
  attr_reader :message
  def initialize(message)
    @message = message
  end

  def perform
    raise 'message'
  end
end

module TestWorkers
  class ThisWorker < ThatWorker
    def perform
      true
    end
  end
end

describe BaseListener::Listener do
  let(:listener)   { BaseListener::Listener.new 'test-appid' }
  let(:connection) { MockBunny.new }
  let(:payload)    { { worker: 'TestWorkers::ThisWorker', message: 'message' } }
  let(:logger)     { MockLogger.new }

  before :each do
    Bunny.stub new: connection
    BaseListener::Logger.stub new: logger
  end

  describe 'initialize' do
    context 'sets' do
      it 'appid' do
        listener.appid.should == 'test-appid'
      end

      it 'logger' do
        listener.logger.should == logger
      end

      it 'connection' do
        listener.connection.should be_a(BaseListener::Connection)
        listener.connection.logger.should == logger
      end
    end

    it 'log info about initialization' do
      listener
      logger.infos.should include('Initialize new BaseListener::Listener with appid = test-appid')
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

      it 'warns about requeue' do
        listener.__send__ :requeue, payload
        logger.warns.should include("requeue message with payload: #{payload.inspect}")
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

        it 'warns about requeue' do
          p = payload.merge requeue_tries: 3
          listener.__send__ :requeue, p
          logger.warns.should include("requeue message with payload: #{p}")
        end
      end

      context 'when requeue_tries is more then max_requeue_tries' do
        it 'doesnt publish payload to exchange' do
          listener.__send__(:exchange).should_not_receive :publish
          listener.__send__ :requeue, payload.merge(requeue_tries: 4)
        end

        it 'errors about message cant be requeued anymore' do
          p = payload.merge requeue_tries: 4
          listener.__send__ :requeue, p
          logger.errors.should include("message with payload: #{p.inspect} can't be requeued anymore")
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
      queue.should_receive(:subscribe).with block: true, ack: true
    end

    it 'infos about new message' do
      listener.subscribe!
      logger.infos.should include("Message with payload: #{payload.inspect} received")
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

    context 'when error happens' do
      before :each do
        queue.payload = payload.merge worker: 'ThatWorker'
      end

      it 'wont rise' do
        expect { listener.subscribe! }.to_not raise_error
      end

      it 'handle it' do
        BaseListener::Handler.any_instance.should_receive(:handle).with do |error, name|
          error.should be_a(RuntimeError)
          name.should == 'BaseListener::Listener'
        end
      end

      it 'errors the error' do
        listener.subscribe!
        logger.errors.should include('message')
      end

      it 'requeue the error' do
        listener.should_receive(:requeue).with payload.merge(worker: 'ThatWorker')
      end
    end
  end

  describe 'channel' do
    it 'get channel from connection' do
      listener.connection.should_receive :channel
      listener.__send__ :channel
    end
  end

  describe 'exchange' do
    it 'get exchange from connection' do
      listener.connection.should_receive :exchange
      listener.__send__ :exchange
    end
  end
end
