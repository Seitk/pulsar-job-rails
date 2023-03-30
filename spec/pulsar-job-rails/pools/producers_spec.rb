require "spec_helper"

RSpec.describe PulsarJob::Pools::Producers do
  let(:topic) { "test-topic" }
  let(:pulsar_client) { instance_double(Pulsar::Client) }
  let(:pulsar_producer) { instance_double(Pulsar::Producer) }

  before do
    allow(PulsarJob::Pools::Client).to receive(:instance_exec).and_yield(pulsar_client)
    allow(pulsar_client).to receive(:create_producer).with(topic, anything).and_return(pulsar_producer)
  end

  describe ".get" do
    it "returns a producer for the given topic" do
      $pulsar_job_pool_producers = { topic => pulsar_producer }
      producer = described_class.get(topic)
      expect(producer).to eq(pulsar_producer)
    end

    it "creates and returns a new producer if one does not exist for the topic" do
      $pulsar_job_pool_producers = {}
      expect(PulsarJob::Pools::Producers).to receive(:create).and_return(pulsar_producer)
      producer = described_class.get(topic)
      expect(producer).to eq(pulsar_producer)
      expect($pulsar_job_pool_producers[topic]).to eq(pulsar_producer)
    end
  end

  describe ".set" do
    it "sets and returns a producer for the given topic" do
      $pulsar_job_pool_producers = {}
      producer = described_class.set(topic, pulsar_producer)
      expect(producer).to eq(pulsar_producer)
      expect($pulsar_job_pool_producers[topic]).to eq(pulsar_producer)
    end
  end

  describe ".create" do
    it "creates and returns a producer for the given topic" do
      expect(PulsarJob::Pools::Client).to receive(:instance_exec).and_yield(pulsar_client)
      expect(pulsar_client).to receive(:create_producer).with(topic, anything).and_return(pulsar_producer)
      producer = described_class.create(topic)
      expect(producer).to eq(pulsar_producer)
    end
  end

  describe ".shutdown" do
    before do
      allow(PulsarJob).to receive(:logger).and_return(double(debug: nil))
    end

    context "when there are producers" do
      it "closes all producers and logs a message" do
        allow(pulsar_producer).to receive(:close)
        $pulsar_job_pool_producers = { topic => pulsar_producer }
        described_class.shutdown
        expect(pulsar_producer).to have_received(:close)
      end
    end

    context "when there are no producers" do
      it "does not raise an error" do
        $pulsar_job_pool_producers = {}
        expect { described_class.shutdown }.not_to raise_error
      end
    end
  end

  describe ".producer_options" do
    it "returns the producer configuration" do
      options = described_class.producer_options
      expect(options.send_timeout_millis).to eq(PulsarJob.configuration.producer_send_timeout_millis)
      expect(options.producer_name).to include("pulsar-job-producer")
    end
  end

  describe ".producer_name" do
    it "returns a producer name string" do
      producer_name = described_class.producer_name
      expect(producer_name).to be_a(String)
      expect(producer_name).to include("pulsar-job-producer")
    end
  end
end
