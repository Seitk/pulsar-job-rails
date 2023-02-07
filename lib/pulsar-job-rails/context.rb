# frozen_string_literal: true

require 'active_support/concern'

module PulsarJob
  module Context
    extend ActiveSupport::Concern

    # Pulsar subscription properties
    attr_writer :subscription
    attr_writer :topic

    # Message properties
    attr_accessor :flatten_payloads
    attr_accessor :payloads
    attr_accessor :created_at

    # Backoff policy
    attr_accessor :backoff

    # Extras
    attr_accessor :deliver_after
    attr_accessor :deliver_at

    # For localization
    attr_accessor :locale
    attr_accessor :timezone

    # Carry the job result
    attr_writer :result

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
