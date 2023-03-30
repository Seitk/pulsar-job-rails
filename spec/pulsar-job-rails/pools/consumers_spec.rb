require "spec_helper"

RSpec.describe PulsarJob::Pools::Consumers do
  let(:topic) { "test-topic" }
  let(:subscription) { "test-subscription" }
  let(:options) { {} }
  let(:pulsar_client) { instance_double(Pulsar::Client) }
  let(:pulsar_consumer) { instance_double(Pulsar::Consumer) }

  before do
    allow(PulsarJob::Pools::Client).to receive(:instance_exec).and_yield(pulsar_client)
    allow(pulsar_client).to receive(:subscribe).with(topic, subscription, options).and_return(pulsar_consumer)
  end

  describe ".get" do
    it "returns a consumer for the given topic" do
      $pulsar_job_pool_consumers = { "#{topic}-#{subscription}" => pulsar_consumer }
      consumer = described_class.get(topic, subscription)
      expect(consumer).to eq(pulsar_consumer)
    end
  end

  describe ".subscribe" do
    it "subscribes to the topic with the provided subscription and options" do
      $pulsar_job_pool_consumers = {}
      expect(PulsarJob::Pools::Client).to receive(:instance_exec).and_yield(pulsar_client)
      consumer = described_class.subscribe(topic, subscription, options)
      expect(consumer).to eq(pulsar_consumer)
      expect(pulsar_client).to have_received(:subscribe).with(topic, subscription, options)
    end
  end

  describe ".shutdown" do
    context "when there are consumers" do
      it "closes all consumers and logs a message" do
        allow(pulsar_consumer).to receive(:close)
        $pulsar_job_pool_consumers = { "#{topic}-#{subscription}" => pulsar_consumer }
        described_class.shutdown
        expect(pulsar_consumer).to have_received(:close)
      end
    end

    context "when there are no consumers" do
      it "does not raise an error" do
        $pulsar_job_pool_consumers = {}
        expect { described_class.shutdown }.not_to raise_error
      end
    end
  end
end
