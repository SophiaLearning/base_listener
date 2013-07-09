module BaseListener
  class Listener
    INTERFACE = %w(queue routing_key)
    attr_reader :appid

    def initialize(appid)
      @appid = appid
    end

    def subscribe!
      queue.bind(exchange, routing_key: routing_key).subscribe(block: true) do |info, meta, payload|
        requeue_if_needed(payload) { worker_for(payload).perform }
      end
    end

    private

    def worker_for(payload)
      payload[:worker].split('::').inject Object do |namespace, name|
        namespace.const_get name
      end.new payload[:message]
    end

    def requeue
    end

    def requeue_if_needed(payload)
      requeue(payload) unless yield
    end

    INTERFACE.each do |name|
      define_method(name) { raise MustBeDefinedInChildClass }
    end

    def connection
      @connection ||= Bunny.new(Config.connection_params).start
    end

    def channel
      @channel ||= connection.create_channel
    end

    def exchange
      @exchange ||= channel.direct "#{Config.prefix}exchange", durable: true
    end
  end
end
