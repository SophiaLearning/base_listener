# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'base_listener/version'

Gem::Specification.new do |spec|
  spec.name          = "base_listener"
  spec.version       = BaseListener::VERSION
  spec.authors       = ["Sidoruk Nikolay"]
  spec.email         = ["nnsidoruk@gmail.com"]
  spec.description   = %q{it's a base listener for RabbitMQ}
  spec.summary       = %q{high level wrapper for Bunny gem}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "bunny", ">= 0.9.0.pre6"
  spec.add_development_dependency "log4r", ">= 1.1.10"
end
