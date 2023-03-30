require "spec_helper"

RSpec.describe PulsarJob::Configuration do
  subject { PulsarJob::Configuration.new }

  describe "defaults" do
    it "sets default values for attributes" do
      expect(subject.pulsar_broker_url).to eq("pulsar://localhost:6650")
      expect(subject.pulsar_broker_max_retries).to eq(PulsarJob::Configuration::DEFAULT_BROKER_MAX_RETRIES)
      expect(subject.pulsar_broker_retry_interval_seconds).to eq(PulsarJob::Configuration::DEFAULT_BROKER_RETRY_INTERVAL_SECONDS)
      expect(subject.pulsar_broker_operation_timeout_seconds).to eq(PulsarJob::Configuration::DEFAULT_BROKER_OPERATION_TIMEOUT_SECONDS)
      expect(subject.pulsar_broker_connection_timeout_ms).to eq(PulsarJob::Configuration::DEFAULT_BROKER_CONNECTION_TIMEOUT_MS)

      expect(subject.default_consumer_type).to eq(PulsarJob::Configuration::DEFAULT_CONSUMER_TYPE)

      expect(subject.consumer_receive_internal_millis).to eq(PulsarJob::Configuration::DEFAULT_CONSUMER_RECEIVE_INTERVAL_MILLIS)
      expect(subject.consumer_receive_timeout_millis).to eq(PulsarJob::Configuration::DEFAULT_CONSUMER_RECEIVE_TIMEOUT_MILLIS)
      expect(subject.consumer_unacked_messages_timeout_millis).to eq(PulsarJob::Configuration::DEFAULT_CONSUMER_UNACKED_MESSAGES_TIMEOUT_MILLIS)

      expect(subject.consumer_batch_receive_policy).to be_a(Pulsar::BatchReceivePolicy)
      expect(subject.consumer_batch_receive_policy.max_num_messages).to eq(PulsarJob::Configuration::DEFAULT_CONSUMER_BATCH_RECEIVE_MAX_NUM_MESSAGES)
      expect(subject.consumer_batch_receive_policy.max_num_bytes).to eq(PulsarJob::Configuration::DEFAULT_CONSUMER_BATCH_RECEIVE_MAX_NUM_BYTES)
      expect(subject.consumer_batch_receive_policy.timeout_ms).to eq(PulsarJob::Configuration::DEFAULT_CONSUMER_BATCH_RECEIVE_TIMEOUT_MILLIS)

      expect(subject.producer_send_timeout_millis).to eq(PulsarJob::Configuration::DEFAULT_PRODUCER_SEND_TIMEOUT_MILLIS)

      expect(subject.logger).to be_a(Logger)
      expect(subject.max_shutdown_wait_seconds).to eq(PulsarJob::Configuration::DEFAULT_MAX_SHUTDOWN_WAIT_SECONDS)
    end
  end

  describe "attribute setters" do
    it "allows setting attribute values" do
      subject.pulsar_broker_url = "pulsar://example.com:6650"
      subject.pulsar_broker_max_retries = 5
      subject.pulsar_broker_retry_interval_seconds = 2
      subject.pulsar_broker_operation_timeout_seconds = 4
      subject.pulsar_broker_connection_timeout_ms = 4000
      subject.default_consumer_type = :failover
      subject.consumer_receive_internal_millis = 500
      subject.consumer_receive_timeout_millis = 6_000
      subject.consumer_unacked_messages_timeout_millis = 120_000

      custom_batch_receive_policy = Pulsar::BatchReceivePolicy.new(50, 0, 15_000)
      subject.consumer_batch_receive_policy = custom_batch_receive_policy

      subject.producer_send_timeout_millis = 5_000

      custom_logger = Logger.new("/dev/null")
      subject.logger = custom_logger
      subject.max_shutdown_wait_seconds = 15

      expect(subject.pulsar_broker_url).to eq("pulsar://example.com:6650")
      expect(subject.pulsar_broker_max_retries).to eq(5)
      expect(subject.pulsar_broker_retry_interval_seconds).to eq(2)
      expect(subject.pulsar_broker_operation_timeout_seconds).to eq(4)
      expect(subject.pulsar_broker_connection_timeout_ms).to eq(4000)

      expect(subject.default_consumer_type).to eq(:failover)

      expect(subject.consumer_receive_internal_millis).to eq(500)
      expect(subject.consumer_receive_timeout_millis).to eq(6_000)
      expect(subject.consumer_unacked_messages_timeout_millis).to eq(120_000)

      expect(subject.consumer_batch_receive_policy).to eq(custom_batch_receive_policy)
      expect(subject.consumer_batch_receive_policy.max_num_messages).to eq(50)
      expect(subject.consumer_batch_receive_policy.max_num_bytes).to eq(0)
      expect(subject.consumer_batch_receive_policy.timeout_ms).to eq(15_000)

      expect(subject.producer_send_timeout_millis).to eq(5_000)

      expect(subject.logger).to eq(custom_logger)
      expect(subject.max_shutdown_wait_seconds).to eq(15)
    end
  end
end
