module BaseListener
  class RetryListener < Listener
    def subscribe!
      queue.bind exchange, routing_key: routing_key
      loop do
        sleep Config.requeue_period
        delivery_info, meta, payload = queue.pop
        if payload.present?
          payload = Marshal.load(payload)
          logger.info "received #{payload.inspect} message"
          perform delivery_info, meta, payload
        end
      end
    end

    def log_name
      'RetryListener'
    end

    private

    def queue
      channel.queue "#{Config.prefix}queues.retry.#{appid}", exclusive: false, durable: true
    end

    def routing_key
      "#{Config.prefix}routing_keys.retry.#{appid}"
    end
  end
end
