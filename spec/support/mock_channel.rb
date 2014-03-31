class MockChannel
  def direct(*args)
    @exchange ||= MockExchange.new
  end

  alias exchange direct

  def queue(*args)
    @queue ||= MockQueue.new
  end

  def acknowledge(*args)
    @acknowledges ||= []
    @acknowledges << args
    true
  end
end
