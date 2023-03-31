require "spec_helper"

RSpec.describe PulsarJob::Consumes::Batched do
  let(:job) { instance_double("PulsarJob::Job", dlq_topic: nil) }
  let(:batched_instance) { described_class.new(job) }
  let(:msg1) { instance_double("Pulsar::Message", data: raw_payload1, redelivery_count: 0) }
  let(:msg2) { instance_double("Pulsar::Message", data: raw_payload2, redelivery_count: 1) }
  let(:raw_payload1) { { some_key: "some_value1" }.to_json }
  let(:raw_payload2) { { some_key: "some_value2" }.to_json }
  let(:handler) { :custom_handler }
  let(:msgs) { [msg1, msg2] }
  let(:pulsar_messages) { instance_double("Pulsar::Messages", to_a: msgs) }
  let(:consumer) { spy("consumer") }

  before do
    allow(batched_instance).to receive(:consumer).and_return(consumer)
    allow(batched_instance).to receive(:msgs).and_return(msgs)
  end

  describe "#receive" do
    it "calls consumer.batch_receive and stores the messages as an array" do
      expect(consumer).to receive(:batch_receive).and_return(pulsar_messages)
      batched_instance.receive
      expect(batched_instance.msgs).to match_array(msgs)
    end
  end

  describe "#raw_payload" do
    it "returns the msgs" do
      expect(batched_instance.raw_payload).to eq(msgs)
    end
  end

  describe "#acknowledge" do
    it "calls consumer.acknowledge for each message in msgs" do
      msgs.each { |m| expect(consumer).to receive(:acknowledge).with(m) }
      batched_instance.acknowledge
    end
  end

  describe "#negative_acknowledge" do
    it "calls consumer.negative_acknowledge for each message in msgs" do
      msgs.each { |m| expect(consumer).to receive(:negative_acknowledge).with(m) }
      batched_instance.negative_acknowledge
    end
  end

  describe "#execute" do
    it "sets job.result after calling the handler with the processed payloads" do
      processed_payloads = msgs.map { |m| JSON.parse(m.data) }
      expect(job).to receive(handler).with(processed_payloads).and_return("result")
      expect(job).to receive(:result=).with("result")
      batched_instance.execute(handler)
    end
  end

  describe "#redelivery_count" do
    it "returns the maximum redelivery_count of msgs or 0 if msgs is empty" do
      expect(batched_instance.redelivery_count).to eq(msgs.map(&:redelivery_count).max)
      allow(batched_instance).to receive(:msgs).and_return([])
      expect(batched_instance.redelivery_count).to eq(0)
    end
  end

  describe "#send_to_dlq" do
    let(:producer) { instance_double("PulsarJob::Produce", publish_raw!: true) }

    context "when job.dlq_topic is not present" do
      it "returns false" do
        expect(batched_instance.send_to_dlq).to be(false)
      end
    end

    context "when job.dlq_topic is present" do
      before do
        allow(job).to receive(:dlq_topic).and_return("test_dlq_topic")
      end

      it "creates a new PulsarJob::Produce instance and publishes raw data of each message to the DLQ topic" do
        expect(PulsarJob::Produce).to receive(:new).with(job: job).and_return(producer)
        msgs.each { |m| expect(producer).to receive(:publish_raw!).with(m.data) }
        batched_instance.send_to_dlq
      end
    end
  end
end
