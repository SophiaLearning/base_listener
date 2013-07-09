class MockLogger
  attr_accessor :level

  %w(warn info error).each do |name|
    define_method "#{name}s" do
      instance_variable_set("@#{name}s", []) if instance_variable_get("@#{name}s").nil?
      instance_variable_get "@#{name}s"
    end

    define_method name do |message|
      public_send("#{name}s") << message
    end
  end
end
