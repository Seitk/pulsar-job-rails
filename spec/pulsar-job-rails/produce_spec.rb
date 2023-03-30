require "spec_helper"

RSpec.describe PulsarJob::Produce do
  let(:job) { double("Job", class: double("JobClass", name: "SampleJob"), _method: :perform, args: {}, topic: "sample-topic") }
  let(:job_class) { double("JobClass", new: job) }
  let(:producer) { double("PulsarJob::Pools::Producers") }

  before do
    allow(PulsarJob::Pools::Producers).to receive(:get).with(job.topic).and_return(producer)
  end

  describe ".publish" do
    it "creates a new instance of the class and publishes the job" do
      mock_producer = double("Produce", publish!: nil)
      expect(PulsarJob::Produce).to receive(:new).with(job: job).and_return(mock_producer)
      expect(mock_producer).to receive(:publish!).with(hash_including({
        job: "SampleJob",
        method: :perform,
        args: [],
      }))
      PulsarJob::Produce.publish(job)
    end
  end

  describe "#initialize" do
    context "when job is provided" do
      it "initializes with the given job" do
        instance = PulsarJob::Produce.new(job: job)
        expect(instance.job).to eq(job)
        expect(instance.producer).to eq(producer)
      end
    end

    context "when job_class is provided" do
      it "initializes with a new instance of job_class" do
        instance = PulsarJob::Produce.new(job_class: job_class)
        expect(instance.job).to eq(job)
        expect(instance.producer).to eq(producer)
      end
    end

    context "when neither job nor job_class is provided" do
      it "raises a JobClassNotDefinedError" do
        expect { PulsarJob::Produce.new }.to raise_error(PulsarJob::Produce::JobClassNotDefinedError, "Job class is not defined")
      end
    end

    describe "#publish!" do
      let(:payload) { { job: "SampleJob", method: :perform, args: {}, sent_at: DateTime.now.to_s } }
      let(:serialized_payload) { payload.to_json }

      before do
        allow(DateTime).to receive(:now).and_return(DateTime.parse("2023-03-29T00:00:00+00:00"))
        allow(producer).to receive(:send)
      end

      it "sends the serialized payload with the producer" do
        instance = PulsarJob::Produce.new(job: job)
        instance.publish!(payload)

        expect(producer).to have_received(:send).with(serialized_payload, {})
      end

      context "when payload is nil" do
        it "generates the payload from the job and sends it with the producer" do
          instance = PulsarJob::Produce.new(job: job)

          instance.publish!(nil)

          expect(producer).to have_received(:send).with(serialized_payload, {})
        end
      end
    end
  end
end
