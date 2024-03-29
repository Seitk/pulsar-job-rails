# frozen_string_literal: true

require "active_support/rescuable"
require "pulsar-job-rails/hooks/callbacks"

module PulsarJob
  class Base
    include Context
    include Hooks::Callbacks
    include ActiveSupport::Rescuable

    # Job properties
    attr_accessor :_method
    attr_accessor :use_raw_payload

    # Message properties
    attr_accessor :payload
    attr_accessor :created_at

    # Carry the job result
    attr_writer :result

    def initialize(*args)
      # Default to perform method, can be overriden by async job
      @_method = :perform
    end

    def perform(*args)
      fail NotImplementedError
    end

    def self.perform_later(*args)
      PulsarJob::Produce.publish(self, *args)
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

    def batched_consume?
      false
    end

    def consumer_options
      ::Pulsar::ConsumerConfiguration.new.tap do |config|
        config.consumer_type = PulsarJob.configuration.default_consumer_type
        config.unacked_messages_timeout_ms = PulsarJob.configuration.consumer_unacked_messages_timeout_millis
        config.batch_receive_policy = PulsarJob.configuration.consumer_batch_receive_policy if batched_consume?
      end
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
