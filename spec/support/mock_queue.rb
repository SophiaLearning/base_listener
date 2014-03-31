class MockQueue
  attr_writer   :info
  attr_accessor :meta, :payload

  def bind(*args)
    self
  end

  def info
    Object.new.tap do |info|
      def info.delivery_tag
        'the-delviery-tag'
      end
    end
  end

  def subscribe(*args)
    yield info, meta, Marshal.dump(payload) if block_given?
  end
end
