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
| pulsar_broker_max_retries | `10` | The number of retry when brokers is failed to connect, it will try out each broker specified in `pulsar_broker_url` and find anyone is up and running |
| pulsar_broker_retry_interval_seconds | `1` | The retry interval of connecting brokers in seconds |
| pulsar_broker_operation_timeout_seconds | `3` | The timeout of broker operation in seconds |
| pulsar_broker_connection_timeout_ms | `3000` | The timeout of broker connection in milliseconds (yea the c++ client uses ms on this) |
| default_subscription | GENERATED | The default subscription name over all jobs |
| default_topic | `nil` | The default topic for jobs |
| logger | `Logger.new(STDOUT)` | The default logger instance to STDOUT |
| max_shutdown_wait_seconds | `60` | Default max gracefully shutdown period in seconds |
| producer_send_timeout_millis | `3000` | Timeout on connecting producer in milliseconds |
| consumer_unacked_messages_timeout_millis | `60000` | Timeout on consumer unacked message in milliseconds |

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
| consumer_options | `nil` | Predefined `Pulsar::ConsumerConfiguration`, override this for per-job configuration |
| payload_as_args? | `true` | By default we will flatten the payload as arguments to compatible with Backburner/ActiveJob interface, override this method and return `false` to obtain the raw payload |
| batched_consume? | `false` | By default jobs are consumed one by one, override this to use batch receive instead. Expected to set `batch_receive_policy` in `consumer_options`. Default batch consumer messages is `30` and timeout in `10` seconds |

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

### Error Handlings

Pulsar Job uses ActiveSupport::Rescuable to provide exception handling for job error handling and reporting.
Error handlers will be examined by error type and choosing the one with highest priority (based on call of rescue_from sequence, child class first).

```
class ApplicationJob < ::PulsarJob::Base
  rescue_from StandardError, with: :report_error

  def report_error(ex)
    # send error reporting to Newrelic or something

    # Re-raise the exception for negative acknowledgement
    raise ex
  end
end

module YourModule
  rescue_from SpecificError, with: :ignore_error

  class SomeJob < ApplicationJob
    def ignore_error(ex)
      Rails.logger.error("SomeJob encountered specific error, ignoring and consider handled successfully")
    end
  end
end
```

### Broker Failure

The underlying pulsar ruby client based on the C++ client, when the client is failed to connect to a broker, an error Pulsar::Error::ConnectError will be raised and crashing your application. Pulsar Job makes use of the service discovery nature of Pulsar brokers to handle retry with broker disconnectivity. By default, Pulsar Job will extract the broker url and connect to a random broker, supposingly Pulsar broker will help to redirect client to a right broker that the topic is correctly located. So when a broker is failed, Pulsar Job will help to reconnect to another broker automatically with a configurable retry.

### Pulsar Job Command Options

| Option | Description |
|--|--|
| data | Payload of producer in JSON string format |
| topic | Specify the topic of consumer, override the topic specified in class |
| subscription | The subscription name of consumer, ignore global config |

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Seitk/pulsar-job-rails. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
