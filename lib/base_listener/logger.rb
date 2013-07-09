module BaseListener
  class Logger
    attr_reader :logged_object, :logger

    def initialize(logged_object)
      @logged_object = logged_object
      @logger        = init_log4r
    end

    private

    def init_log4r
      Log4r::Logger.new(logged_object.log_name).tap do |logger|
        logger.outputters << Log4r::Outputter.stdout
        logger.outputters << rolling_file_outputter unless Config.log_path.nil?
        logger.level     =  Log4r::DEBUG
      end
    end

    def rolling_file_outputter
      Log4r::RollingFileOutputter.new(
        logged_object.log_name,
        maxsize: 1024*1024*5,
        filename: File.join(Config.log_path, "#{logged_object.log_name.underscore}.#{Process.pid}..log")
      )
    end

    #warn, error, info methods
    %w(warn error info).each do |method_name|
      define_method method_name do |message|
        logger.public_send method_name, message
      end
    end
  end
end
