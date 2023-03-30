require "spec_helper"

RSpec.describe PulsarJob::Pools::Client do
  let(:config) { instance_double(Pulsar::ClientConfiguration) }
  let(:pulsar_client) { instance_double(Pulsar::Client) }
  let(:host) { "localhost:6650" }

  before do
    allow(Pulsar::ClientConfiguration).to receive(:new).and_return(config)
    allow(config).to receive(:operation_timeout_seconds=)
    allow(config).to receive(:connection_timeout_ms=)
    allow(Pulsar::Client).to receive(:new).and_return(pulsar_client)
    allow(PulsarJob.configuration).to receive(:pulsar_broker_url).and_return("pulsar://#{host}")
  end

  describe ".instance" do
    it "returns the global instance of pulsar client" do
      $pulsar_job_pool_client = pulsar_client
      expect(described_class.instance).to eq(pulsar_client)
    end
  end

  describe ".connect" do
    it "creates a new Pulsar client with the given host and configuration" do
      described_class.connect(host)
      expect(Pulsar::Client).to have_received(:new).with("pulsar://#{host}", config)
    end
  end

  describe ".instance_exec" do
    let(:block) { Proc.new { |client| client } }
    it "executes the block with a connected Pulsar client" do
      result = described_class.instance_exec(&block)

      expect(result).to eq(pulsar_client)
      expect(Pulsar::Client).to have_received(:new).with("pulsar://#{host}", config)
    end

    context "when there is a connection error" do
      before do
        allow(PulsarJob.configuration).to receive(:pulsar_broker_max_retries).and_return(1)
        allow(PulsarJob.configuration).to receive(:pulsar_broker_retry_interval_seconds).and_return(1)
        allow(Pulsar::Client).to receive(:new).and_raise(Pulsar::Error::ConnectError)
      end

      it "retries connection with a different broker up to the configured number of max retries" do
        expect {
          described_class.instance_exec(&block)
        }.to raise_error(PulsarJob::Pools::Client::InvalidClientConfigirationError, /Unable to connect to any broker after 1 retries/)
      end
    end
  end

  describe ".shutdown" do
    it "closes the Pulsar client" do
      allow(pulsar_client).to receive(:close)
      allow(PulsarJob).to receive(:logger).and_return(double(debug: nil))

      $pulsar_job_pool_client = pulsar_client
      described_class.shutdown
      expect(pulsar_client).to have_received(:close)
      expect(PulsarJob.logger).to have_received(:debug).with("Pulsar client closed")
    end
  end

  describe "private methods" do
    describe ".broker_hosts" do
      it "returns an array of shuffled broker hosts" do
        broker_hosts = described_class.send(:broker_hosts)

        expect(broker_hosts).to include(host)
      end

      context "when the configuration has an invalid URL" do
        before do
          allow(PulsarJob.configuration).to receive(:pulsar_broker_url).and_return("invalid_url")
        end

        it "raises an InvalidClientConfigirationError" do
          expect {
            described_class.send(:broker_hosts)
          }.to raise_error(PulsarJob::Pools::Client::InvalidClientConfigirationError, "Invalid client configuration")
        end
      end
    end
  end
end
