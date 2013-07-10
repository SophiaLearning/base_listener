# BaseListener
It's a wrapper for Bunny gem.
It's designed to use direct exchange

## Installation

Add this line to your application's Gemfile:

    gem 'base_listener'

And then execute:

    $ bundle

## Usage
### Configuration
There are several points which may be configured:
```ruby
  #connection_params, hash with symbolized keys, default = empty hash
  BaseListener::Config.connection_params = {
    :host      => "localhost",
    :port      => 5672,
    :ssl       => false,
    :vhost     => "/",
    :user      => "guest",
    :pass      => "guest",
    :heartbeat => 0,
    :frame_max => 131072
  }

  #prefix, string, will be append to exchange name, requeue queue routing key and name, default - empty string
  BaseListener::Config.prefix = 'my.namespace.'

  #requeue_period in seconds, every the period RetryListener check retry queue, default - 10
  BaseListener::Config.prefix = 10

  #handler, handler for exceptions, default = just resque
  BaseListener::Config.handler = Exceptional

  #log_path, path to dir where log will be written. Log4r will not write text logs when not present.
  BaseListener::Config.log_path = File.join(Rails.root, 'log')
```
###Listeners
Create own listener and inherit it from BaseListener::Listener
```ruby
  class MyListener < BaseListener::Listener
    #you must define queue and routing_key methods
    #you may redefine any methods you want to
    private
    def queue
      channel.queue "my_namespace.queues.my_queue", exclusive: false, durable: true
    end

    def routing_key
      "routing_keys.my_queue.key"
    end
  end
```
Make rake task to run the listener. Also you should create task for retry listener
```ruby
namespace :listeners do
  desc 'run log listener'
  task log: :environment do
    LogListener.new(CONFIG[:appid]).subscribe!
  end

  desc 'run retry listener'
  task retry: :environment do
    BaseListener::RetryListener.new(CONFIG[:appid]).subscribe!
  end
end
```

###Workers
Listener is expected to receive dumped with Marshal hash with at least two keys: message and worker
payload[:worker] will be constantize to worker class, worker instance will be initialized with payload[:message],
perform method will be called.
```ruby
  class MyTrullyWorker
    def initialize(message)
      @message = message
    end

    def perform
      #do something
    end
  end
  payload = { worker: 'MyTrullyWorker', message: 'the message' }
```

###appid
Listener should be spulied with appid, which will be used as postfix for requeue.
Also it is good idea to use the same appid for all queues and routing keys to create namespaces for each environment
