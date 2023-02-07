# frozen_string_literal: true

module PulsarJob
  class Base
    include PulsarJob::Callbacks

    # Pulsar subscription properties
    attr_writer :subscription
    attr_writer :topic

    # Job properties
    attr_accessor :method
    attr_accessor :use_raw_payload

    # Message properties
    attr_accessor :payload
    attr_accessor :created_at

    # Pulsar consume options
    attr_accessor :consumer_options
    attr_accessor :backoff
    attr_accessor :deliver_after
    attr_accessor :deliver_at

    # For localization
    attr_accessor :locale
    attr_accessor :timezone

    # Carry the job result
    attr_writer :result

    def initialize(*args)
      # Default to perform method, can be overriden by async job
      @method = :perform
    end

    def perform(*args)
      fail NotImplementedError
    end

    def self.perform_later
      PulsarJob::Producer.publish(self, *args)
    end

    def subscription
      @subscription || ::PulsarJob.configuration.default_subscription || auto_subscription
    end

    def topic
      @topic || ::PulsarJob.configuration.default_topic
    end

    def payload_as_args?
      use_raw_payload != true
    end

    # Override and true if you want to use raw payload instead of args only
    def use_raw_payload
      false
    end

    def consumer_options
      {
        consumer_type: consumer_type,
      }
    end

    def consumer_type
      # https://github.com/instructure/pulsar-client-ruby/blob/2.6.1-beta.2/lib/pulsar/consumer_configuration.rb#L29
      ::PulsarJob.configuration.default_consumer_type || :shared
    end

    def context_valid?
      return false if subscription.nil? || topic.nil?

      true
    end

    private

    def auto_subscription
      host_id =
        if defined?(Socket)
          Socket.gethostname
        else
          SecureRandom.hex(8)
        end
      "pulsar-job-subscription-#{host_id}"
    end
  end
end
