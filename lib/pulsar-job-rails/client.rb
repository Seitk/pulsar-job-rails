# frozen_string_literal: true

module PulsarJob
  module Client
    class << self
      def instance
        @client ||= ::Pulsar::Client.new(PulsarJob.configuration.pulsar_broker_url, Pulsar::ClientConfiguration.new)
      end
    end
  end
end
