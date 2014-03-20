module BaseListener
  class Listener
    INTERFACE = %w(queue routing_key)
    attr_reader :appid, :logger, :connection

    def initialize(appid)
      @appid = appid
      @logger = Logger.new self
      @connection = Connection.new @logger
      logger.info "Initialize new #{log_name} with appid = #{appid}"
    end

    def subscribe!
      queue.bind(exchange, routing_key: routing_key).subscribe(block: true, ack: true) do |info, meta, payload|
        perform info, meta, Marshal.load(payload)
        channel.acknowledge(info.delivery_tag, false)
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

    #META interface
    INTERFACE.each do |name|
      define_method(name) { raise MustBeDefinedInChildClass }
    end

    #META def channel and def connection
    %w(channel exchange).each do |name|
      define_method(name) { connection.public_send name }
    end

    def handle_errors
      yield
    rescue Exception => e
      logger.error e.message
      Config.handler.handle e, self.class.name
      false
    end
  end
end
