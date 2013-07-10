module BaseListener
  class Connection
    attr_reader :logger

    def initialize(logger = nil)
      @logger = logger || Logger.new(self)
    end

    def channel
      @channel ||= connection.create_channel
    end

    def exchange
      @exchange ||= channel.direct "#{Config.prefix}exchange", durable: true
    end

    def log_name
      'BunnyConnection'
    end

    private

    def connection
      @connection ||= Bunny.new(Config.connection_params).start.tap do |c|
        logger.info "New RabbitMQ connection initialized with host #{c.host}:#{c.port} and status #{c.status}"
      end
    end
  end
end
