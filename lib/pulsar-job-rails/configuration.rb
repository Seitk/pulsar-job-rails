# frozen_string_literal: true

module PulsarJob
  class Configuration
    attr_accessor :pulsar_broker_url
    attr_accessor :pulsar_broker_max_retries
    attr_accessor :pulsar_broker_retry_interval_seconds
    attr_accessor :pulsar_broker_operation_timeout_seconds
    attr_accessor :pulsar_broker_connection_timeout_ms

    attr_accessor :default_subscription
    attr_accessor :default_topic
    attr_accessor :default_consumer_type

    attr_accessor :logger
    attr_accessor :max_shutdown_wait_seconds

    attr_accessor :producer_send_timeout_millis

    DEFAULT_BROKER_MAX_RETRIES = 10 # 10 times over all broker nodes
    DEFAULT_BROKER_RETRY_INTERVAL_SECONDS = 1 # 1 seconds on retry
    DEFAULT_BROKER_OPERATION_TIMEOUT_SECONDS = 3 # timeout on connecting broker
    DEFAULT_BROKER_CONNECTION_TIMEOUT_MS = 3000 # 3 seconds timeout on connecting broker
    DEFAULT_MAX_SHUTDOWN_WAIT_SECONDS = 10 # 10 seconds
    DEFAULT_PRODUCER_SEND_TIMEOUT_MILLIS = 3000 # 3 seconds timeout on sending message

    def initialize
      @pulsar_broker_url = "pulsar://localhost:6650"
      @logger = Logger.new(STDOUT)
      @max_shutdown_wait_seconds = DEFAULT_MAX_SHUTDOWN_WAIT_SECONDS
      @producer_send_timeout_millis = DEFAULT_PRODUCER_SEND_TIMEOUT_MILLIS
      @pulsar_broker_max_retries = DEFAULT_BROKER_MAX_RETRIES
      @pulsar_broker_retry_interval_seconds = DEFAULT_BROKER_RETRY_INTERVAL_SECONDS
      @pulsar_broker_operation_timeout_seconds = DEFAULT_BROKER_OPERATION_TIMEOUT_SECONDS
      @pulsar_broker_connection_timeout_ms = DEFAULT_BROKER_CONNECTION_TIMEOUT_MS
    end
  end
end
