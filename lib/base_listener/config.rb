module BaseListener
  class Config
    include Singleton
    attr_accessor :log_path
    attr_writer :connection_params, :prefix

    class << self
      %w(connection_params prefix log_path).each do |name|
        define_method name do
          instance.public_send name
        end

        define_method "#{name}=" do |*args|
          instance.public_send "#{name}=", *args
        end
      end
    end

    def connection_params
      @connection_params || {}
    end

    def prefix
      @prefix || ''
    end
  end
end
