module BaseListener
  class Listener
    INTERFACE = %w(queue routing_key)
    attr_reader :appid, :logger

    def initialize(appid)
      @appid = appid
      @logger = Logger.new self
      logger.info "Initialize new #{log_name} with appid = #{appid}"
    end

    def subscribe!
      queue.bind(exchange, routing_key: routing_key).subscribe(block: true) do |info, meta, payload|
        perform info, meta, Marshal.load(payload)
      end
    end

    def log_name
      self.class.name
    end

    private

    def perform(info, meta, payload)
      logger.info "Message with payload: #{payload.inspect} received"
      requeue_if_needed(payload) { handle_errors { worker_for(payload).perform } }
    end

    def worker_for(payload)
      payload[:worker].split('::').inject Object do |namespace, name|
        namespace.const_get name
      end.new payload[:message]
    end

    def requeue(payload)
      payload[:requeue_tries] ||= 0
      if payload[:requeue_tries] <=  max_requeue_tries
        payload[:requeue_tries] +=  1
        logger.warn "requeue message with payload: #{payload.inspect}"
        exchange.publish Marshal.dump(payload), routing_key: "#{Config.prefix}routing_keys.retry.#{appid}", persisted: true
      else
        logger.error "message with payload: #{payload.inspect} can't be requeued anymore"
      end
    end

    def max_requeue_tries
      3
    end

    def requeue_if_needed(payload)
      requeue(payload) unless yield
    end

    INTERFACE.each do |name|
      define_method(name) { raise MustBeDefinedInChildClass }
    end

    def connection
      @connection ||= Bunny.new(Config.connection_params).start.tap do |c|
        logger.info "New RabbitMQ connection initialized with host #{c.host}:#{c.port} and status #{c.status}"
      end
    end

    def channel
      @channel ||= connection.create_channel
    end

    def exchange
      @exchange ||= channel.direct "#{Config.prefix}exchange", durable: true
    end

    def handle_errors
      yield
    rescue => e
      Config.handler.handle e, self.class.name
      logger.error e.message
      false
    end
  end
end
