# frozen_string_literal: true

require "active_support/concern"

module PulsarJob
  module Context
    extend ActiveSupport::Concern

    # Pulsar subscription properties
    attr_writer :subscription
    attr_writer :topic

    # Message properties
    attr_accessor :args
    attr_accessor :payload
    attr_accessor :created_at

    # Pulsar consume options
    attr_accessor :backoff
    attr_accessor :consumer_options
    attr_accessor :backoff # NOT SUPPORTED YET
    attr_accessor :deliver_after
    attr_accessor :deliver_at

    # Extras
    attr_accessor :deliver_after
    attr_accessor :deliver_at

    # For localization
    attr_accessor :locale
    attr_accessor :timezone

    # Carry the job result
    attr_writer :result

    def reset_job_context
      @args = nil
      @payload = nil
      @created_at = nil
      @result = nil
    end

    def subscription
      @subscription || ::PulsarJob.configuration.default_subscription || auto_subscription
    end

    def topic
      @topic || ::PulsarJob.configuration.default_topic
    end

    def context_valid?
      return false if subscription.nil? || topic.nil?

      true
    end

    private

    def auto_subscription
      host_id = if defined?(Socket)
          Socket.gethostname
        else
          SecureRandom.hex(8)
        end
      "pulsar-job-subscription-#{host_id}"
    end
  end
end
