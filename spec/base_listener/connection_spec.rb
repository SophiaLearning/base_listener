require 'spec_helper'

describe BaseListener::Connection do
  let(:connection) { BaseListener::Connection.new logger }
  let(:bunny_connection) { MockBunny.new }
  let(:logger)     { MockLogger.new }

  before { Bunny.stub new: bunny_connection }

  describe '#connection' do
    it 'initialize bunny with correct params' do
      Bunny.should_receive(:new).with(BaseListener::Config.connection_params).and_return(bunny_connection)
      connection.__send__ :connection
    end

    it 'starts connection' do
      bunny_connection.should_receive(:start).and_return(bunny_connection)
      connection.__send__ :connection
    end

    it 'writes connection to @connection' do
      connection.__send__ :connection
      connection.instance_variable_get('@connection').should == bunny_connection
    end

    it 'logs info about new connection' do
      connection.__send__ :connection
      logger.infos.should include(
        "New RabbitMQ connection initialized with host #{bunny_connection.host}:#{bunny_connection.port} and status #{bunny_connection.status}"
      )
    end
  end

  describe '#channel' do
    it 'creates new channel' do
      bunny_connection.should_receive :create_channel
      connection.__send__ :channel
    end

    it 'writes it to @channel' do
      connection.__send__ :channel
      connection.instance_variable_get('@channel').should == bunny_connection.create_channel
    end
  end

  describe '#exchange' do
    it 'creates direct exchange' do
      bunny_connection.__send__(:channel).should_receive(:direct).with 'exchange', durable: true
      connection.__send__ :exchange
    end

    it 'writes it to @exchange' do
      connection.__send__ :exchange
      connection.instance_variable_get('@exchange').should == bunny_connection.create_channel.direct
    end
  end
end
