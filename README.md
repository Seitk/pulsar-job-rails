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

Besides the `perform`, you can override some methods to configure the job consume options.

| Method Name | Default | Description |
|--|--|--|
| subscription | `PulsarJob.configuration.default_subscription` | The subscription name of job |
| topic | `PulsarJob.configuration.default_topic` | The topic of consumer |
| method | `perform` | The default caller when the job consumes |
| deliver_after | `nil` | The delay on job execution in milliseconds |
| deliver_at | `nil` | The exact execution time in unix timestamp |
| payload_as_args? | `true` | By default we will flatten the payload as arguments to compatible with Backburner/ActiveJob interface, override this method and return `false` to obtain the raw payload |

### Using Existing Classes

WIP

### Using Consumer

Start the consumer with `pulsar_job consume` with the job class name and module.

```
bundle exec pulsar_job consume YourModule::SomeJob
```

#### Acknowledgment and Negative Acknowledgment

Consumer will automatically perform acknowledgment. if there is any error raised within the `perform` execution, it will fire nack instead.

#### Gracefully Shutdown

By default pulsar job will have a `60` seconds gracefully shutdown period, you might override the value changing `max_shutdown_wait_seconds` by `PulsarJob.configure` or updating `PulsarJob.configuration` directly.


### Producer


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

### Using Producer

#### One-off Message Produce

You can produce an one-off message with `pulsar produce` command, using `-d` or `--data` to specify the payload in JSON string format.

```bash
bundle exec pulsar_job produce YourModule::SomeJob -d "[\"EXECUTION_ID\", \"ANOTHER_ARGUMENT\"]"
```


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Seitk/pulsar-job-rails. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
