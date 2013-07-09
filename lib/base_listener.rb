require 'singleton'
require 'bunny'
require "base_listener/version"
require "base_listener/config"
require "base_listener/listener"


module BaseListener
  class MustBeDefinedInChildClass < Interrupt
  end
end
