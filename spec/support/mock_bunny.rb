class MockBunny
  PARAMS = {
    host:      "localhost",
    port:      5672,
    ssl:       false,
    vhost:     "/",
    user:      "guest",
    pass:      "guest",
    heartbeat: 0,
    frame_max: 131072
  }

  PARAMS.each { |name, return_me| define_method(name) { return_me } }

  def start
    self
  end

  def create_channel
    @channel ||= MockChannel.new
  end

  alias channel create_channel

  def port
    PARAMS[:port]
  end

  def host
    PARAMS[:host]
  end

  def status
    :open
  end
end
