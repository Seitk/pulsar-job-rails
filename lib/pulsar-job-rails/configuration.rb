# frozen_string_literal: true

module PulsarJob
  class Configuration
    attr_accessor :pulsar_broker_url

    attr_accessor :default_subscription
    attr_accessor :default_topic
    attr_accessor :default_consumer_type

    attr_accessor :logger
    attr_accessor :max_shutdown_wait_seconds

    attr_accessor :producer_send_timeout_millis

    DEFAULT_MAX_SHUTDOWN_WAIT_SECONDS = 10 # 10 seconds
    DEFAULT_PRODUCER_SEND_TIMEOUT_MILLIS = 3000 # 3 seconds

    def initialize
      @pulsar_broker_url = "pulsar://localhost:6650"
      @logger = Logger.new(STDOUT)
      @max_shutdown_wait_seconds = DEFAULT_MAX_SHUTDOWN_WAIT_SECONDS
      @producer_send_timeout_millis = DEFAULT_PRODUCER_SEND_TIMEOUT_MILLIS
    end
  end
end
