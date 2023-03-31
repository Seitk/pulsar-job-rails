require "spec_helper"

RSpec.describe PulsarJob::Consumes::One do
  let(:job) { instance_double("PulsarJob::Job", dlq_topic: nil) }
  let(:one_instance) { described_class.new(job) }
  let(:msg) { instance_double("Pulsar::Message", data: raw_payload, message_id: "message_id", redelivery_count: 0) }
  let(:raw_payload) { { some_key: "some_value" }.to_json }
  let(:handler) { :custom_handler }
  let(:consumer) { spy("consumer") }

  before do
    allow(one_instance).to receive(:consumer).and_return(consumer)
    allow(one_instance).to receive(:msg).and_return(msg)
  end

  describe "#receive" do
    it "calls consumer.receive with the configured timeout" do
      expect(consumer).to receive(:receive).with(PulsarJob.configuration.consumer_receive_timeout_millis)
      one_instance.receive
    end
  end

  describe "#raw_payload" do
    it "returns the msg" do
      expect(one_instance.raw_payload).to eq(msg)
    end
  end

  describe "#acknowledge" do
    it "calls consumer.acknowledge with the msg" do
      expect(consumer).to receive(:acknowledge).with(msg)
      one_instance.acknowledge
    end
  end

  describe "#negative_acknowledge" do
    it "calls consumer.negative_acknowledge with the msg" do
      expect(consumer).to receive(:negative_acknowledge).with(msg)
      one_instance.negative_acknowledge
    end
  end

  describe "#execute" do
    context "when job.payload_as_args? is true" do
      before do
        allow(job).to receive(:payload_as_args?).and_return(true)
      end

      it "sets job.payload, job.args and job.result correctly" do
        payload = JSON.parse(raw_payload)
        expect(job).to receive(:payload=).with(payload)
        expect(job).to receive(:args=).with(payload["args"])
        expect(job).to receive(handler).and_return("result")
        expect(job).to receive(:result=).with("result")
        one_instance.execute(handler)
      end
    end

    context "when job.payload_as_args? is false" do
      before do
        allow(job).to receive(:payload_as_args?).and_return(false)
      end

      it "sets job.payload and job.result correctly" do
        expect(job).to receive(:payload=).with(JSON.parse(raw_payload))
        expect(job).to receive(handler).with(payload: JSON.parse(raw_payload), message_id: msg.message_id, raw: msg).and_return("result")
        expect(job).to receive(:result=).with("result")
        one_instance.execute(handler)
      end
    end
  end

  describe "#redelivery_count" do
    it "returns the redelivery_count of msg or 0 if msg is nil" do
      expect(one_instance.redelivery_count).to eq(msg.redelivery_count)
      allow(one_instance).to receive(:msg).and_return(nil)
      expect(one_instance.redelivery_count).to eq(0)
    end
  end

  describe "#send_to_dlq" do
    let(:producer) { instance_double("PulsarJob::Produce", publish_raw!: true) }

    context "when job.dlq_topic is not present" do
      it "returns false" do
        expect(one_instance.send_to_dlq).to be(false)
      end
    end

    context "when job.dlq_topic is present" do
      before do
        allow(job).to receive(:dlq_topic).and_return("test_dlq_topic")
      end

      it "creates a new PulsarJob::Produce instance and publishes raw data to the DLQ topic" do
        expect(PulsarJob::Produce).to receive(:new).with(job: job).and_return(producer)
        expect(producer).to receive(:publish_raw!).with(msg.data)
        one_instance.send_to_dlq
      end
    end
  end
end
