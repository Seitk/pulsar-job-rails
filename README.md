# Pulsar::Job::Rails

Pulsar Job provides a framework to work with `pulsar-client-ruby` for consuming and producing message with similar experience on ActiveJob and Backburner.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'pulsar-job-rails'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install pulsar-job-rails

## Usage

### Global Configuration

You can setup some global configuration on Pulsar Job

| Variable | Default | Description |
|--|--|--|
| pulsar_broker_url | `nil` | The pulsar broker url, multiple brokers separated with comma. <br>E.g. pulsar://broker1.cluster.com:6650,broker2.cluster.com:6650 |
| default_subscription | GENERATED | The default subscription name over all jobs |
| default_topic | `nil` | The default topic for jobs |
| logger | `Logger.new(STDOUT)` | The default logger instance to STDOUT |
| max_shutdown_wait_seconds | `60` | Default max gracefully shutdown period in seconds |

### Job Class Definition

Pulsar Job expects consumer to inherit `PulsarJob::Base` and provide a `perform` method as the consume handler.

```ruby
module YourModule
  class SomeJob < ::PulsarJob::Base
    def perform(*args)
      # Your work here
    end
  end
end
```

You can override some methods to configure the job consume options.

| Method Name | Default | Description |
|--|--|--|
| subscription | `PulsarJob.configuration.default_subscription` | The subscription name of job |
| topic | `PulsarJob.configuration.default_topic` | The topic of consumer |
| method | `perform` | The handler method when the job consumes |
| deliver_after | `nil` | The delay on job execution in milliseconds |
| deliver_at | `nil` | The exact execution time in unix timestamp |
| payload_as_args? | `true` | By default we will flatten the payload as arguments to compatible with Backburner/ActiveJob interface, override this method and return `false` to obtain the raw payload |

### Async Wrapper

Pulsar Job provides a similar interface of Backburner for a non-job model/class to perform asynchronous execution.

You can use the concern to extend existing model/class

```ruby
include PulsarJob::Asyncable
```

Then you can call `.async` (both on class or instance) to wrap the subject and method as asynchronous call

```ruby
# Original static method
SomeClass.execute_something

# Converted with async
SomeClass.async.execute_something

# Original instance method
instance = SomeClass.new
instance.execute_something

# Converted with async
instance.async.execute_something
```

Noted that the method call following `.async` or `.set` will be the method handler from consuming.

Since non-job model/class has no topic/subscription configuration, you will need to configure that with `.set` call on the async wrapper. The supported options are bascially same as job consume options we have above.

```ruby
SomeClass.async.set(topic: 'persistent://property/namespace/action').execute_something

instance.set(topic: 'persistent://property/namespace/action').execute_something
```

#### Using Wrapper Dynamically

Sometimes you might need to toggle the method execution from asynchronous to synchronous for testing or debug purpose, Pulsar Job provides another way to wrap the static/instance method with Async Wrapper separately. Which means you might choose to execute async or sync by toggling the `PulsarJob::Asyncable.wrap` logic without changing the codebase in your original logic.

The `PulsarJob::Asyncable.wrap` will alias the original method into `"#{method_name}_without_async"`, which keeping the ability for you to run it in synchronous.

```ruby
PulsarJob::Asyncable.wrap(SomeClass, :some_static_method, {
  topic: 'persistent://property/namespace/action',
})

PulsarJob::Asyncable.wrap(SomeClass, :some_instance_method, {
  topic: 'persistent://property/namespace/action',
})

# Use the original call to trigger async execution
SomeClass.some_static_method
instance.some_instance_method

# Execute original method
SomeClass.some_static_method_without_async
instance.some_instance_method_without_async
```

### Using Consumer

Start the consumer with `pulsar_job consume` with the job class name and module.

```
bundle exec pulsar_job consume YourModule::SomeJob
```

For model/class with Async Wrapper, the class name, method and arguments are passed as payload, and you will need to consume that with `PulsarJob::Async::Wrapper` along with `-t` or `--topic` option

```
bundle exec pulsar_job consume PulsarJob::Async::Wrapper -t persistent://property/namespace/action
```

The async wrapper will perform call with given class, method and arguments in the message.

#### Acknowledgment and Negative Acknowledgment

Consumer will automatically perform acknowledgment. if there is any error raised within the `perform` execution, it will fire nack instead.

#### Gracefully Shutdown

By default pulsar job will have a `60` seconds gracefully shutdown period, you might override the value changing `max_shutdown_wait_seconds` by `PulsarJob.configure` or updating `PulsarJob.configuration` directly.

### Producer

To perform an asynchronous execution with Pulsar Job, use `.perform_later` 

```ruby
job = YourModule::SomeJob.new
job.payload = { count: 100 }
job.perform_later
```

For non-job production, see Async Wrapper section

#### One-off Message Produce

You can produce an one-off message with `pulsar produce` command, using `-d` or `--data` to specify the payload in JSON string format.

```bash
bundle exec pulsar_job produce YourModule::SomeJob -d "[\"EXECUTION_ID\", \"ANOTHER_ARGUMENT\"]"
```

### Callbacks

Pulsar Job provides callback on `perform` and `enqueue`, you can register callbacks with the job class.

```ruby
class ApplicationJob < ::PulsarJob::Base
  before_perform :trace_start
  after_perform :trace_end

  def trace_start
    @transaction = Tracer.start_transaction
  end

  def trace_end
    @transaction.finish if @transaction
  end
end

module YourModule
  class SomeJob < ApplicationJob
    def perform(*args)
      # Your work here
    end
  end
end
```

### Pulsar Job Command Options

| Option | Description |
|--|--|--|
| data | Payload of producer in JSON string format |
| topic | Specify the topic of consumer, override the topic specified in class |
| subscription | The subscription name of consumer, ignore global config |

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Seitk/pulsar-job-rails. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
