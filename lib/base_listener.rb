require 'singleton'
require 'bunny'
require 'log4r'
require 'log4r/outputter/syslogoutputter'
require 'pry'
require "base_listener/version"
require "base_listener/config"
require "base_listener/logger"
require "base_listener/connection"
require "base_listener/listener"
require "base_listener/retry_listener"
require "base_listener/handler"


module BaseListener
  class MustBeDefinedInChildClass < Interrupt
  end
end
