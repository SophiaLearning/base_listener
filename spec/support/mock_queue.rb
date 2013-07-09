class MockQueue
  attr_accessor :info, :meta, :payload
  def bind(*args)
    self
  end

  def subscribe(*args)
    yield info, meta, Marshal.dump(payload) if block_given?
  end
end
