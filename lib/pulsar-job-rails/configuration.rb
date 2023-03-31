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

    attr_accessor :consumer_receive_internal_millis
    attr_accessor :consumer_receive_timeout_millis
    attr_accessor :consumer_unacked_messages_timeout_millis
    attr_accessor :consumer_batch_receive_policy
    attr_accessor :consumer_max_redelivery_count

    attr_accessor :producer_send_timeout_millis

    attr_accessor :logger
    attr_accessor :max_shutdown_wait_seconds

    attr_accessor :producer_send_timeout_millis

    DEFAULT_CONSUMER_TYPE = :shared

    DEFAULT_BROKER_MAX_RETRIES = 10 # 10 times over all broker nodes
    DEFAULT_BROKER_RETRY_INTERVAL_SECONDS = 1 # 1 seconds on retry
    DEFAULT_BROKER_OPERATION_TIMEOUT_SECONDS = 3 # timeout on connecting broker
    DEFAULT_BROKER_CONNECTION_TIMEOUT_MS = 3000 # 3 seconds timeout on connecting broker
    DEFAULT_MAX_SHUTDOWN_WAIT_SECONDS = 10 # 10 seconds
    DEFAULT_PRODUCER_SEND_TIMEOUT_MILLIS = 3000 # 3 seconds timeout on sending message

    DEFAULT_CONSUMER_RECEIVE_INTERVAL_MILLIS = 300 # 300ms sleep after each message consume
    DEFAULT_CONSUMER_RECEIVE_TIMEOUT_MILLIS = 5_000 # 5 seconds timeout on consumer receive
    DEFAULT_CONSUMER_UNACKED_MESSAGES_TIMEOUT_MILLIS = 60_000 # 60 seconds timeout on unack message
    DEFAULT_CONSUMER_BATCH_RECEIVE_MAX_NUM_MESSAGES = 30 # by default taking 30 messages at once
    DEFAULT_CONSUMER_BATCH_RECEIVE_MAX_NUM_BYTES = 0
    DEFAULT_CONSUMER_BATCH_RECEIVE_TIMEOUT_MILLIS = 10_000 # 10 seconds timeout on batch receive
    DEFAULT_CONSUMER_MAX_REDELIVERY_COUNT = 2_147_483_647 # Unlimited redelivery

    def initialize
      @pulsar_broker_url = "pulsar://localhost:6650"
      @logger = Logger.new(STDOUT)
      @max_shutdown_wait_seconds = DEFAULT_MAX_SHUTDOWN_WAIT_SECONDS

      @default_consumer_type = DEFAULT_CONSUMER_TYPE

      # Broker
      @pulsar_broker_max_retries = DEFAULT_BROKER_MAX_RETRIES
      @pulsar_broker_retry_interval_seconds = DEFAULT_BROKER_RETRY_INTERVAL_SECONDS
      @pulsar_broker_operation_timeout_seconds = DEFAULT_BROKER_OPERATION_TIMEOUT_SECONDS
      @pulsar_broker_connection_timeout_ms = DEFAULT_BROKER_CONNECTION_TIMEOUT_MS

      # Consumer
      @consumer_receive_internal_millis = DEFAULT_CONSUMER_RECEIVE_INTERVAL_MILLIS
      @consumer_receive_timeout_millis = DEFAULT_CONSUMER_RECEIVE_TIMEOUT_MILLIS
      @consumer_unacked_messages_timeout_millis = DEFAULT_CONSUMER_UNACKED_MESSAGES_TIMEOUT_MILLIS
      @consumer_batch_receive_policy = ::Pulsar::BatchReceivePolicy.new(
        DEFAULT_CONSUMER_BATCH_RECEIVE_MAX_NUM_MESSAGES,
        DEFAULT_CONSUMER_BATCH_RECEIVE_MAX_NUM_BYTES,
        DEFAULT_CONSUMER_BATCH_RECEIVE_TIMEOUT_MILLIS
      )
      @consumer_max_redelivery_count = DEFAULT_CONSUMER_MAX_REDELIVERY_COUNT

      # Producer
      @producer_send_timeout_millis = DEFAULT_PRODUCER_SEND_TIMEOUT_MILLIS
    end
  end
end
