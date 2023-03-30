require "spec_helper"
require "pulsar-job-rails"

RSpec.describe PulsarJob::Base do
  let(:job_class) do
    Class.new(PulsarJob::Base) do
      def perform(*args)
        "Hello, world!"
      end
    end
  end

  let(:job) { job_class.new }

  describe "#perform" do
    it "raises a NotImplementedError if not implemented" do
      expect { PulsarJob::Base.new.perform }.to raise_error(NotImplementedError)
    end

    it "calls the perform method when implemented" do
      expect(job.perform).to eq("Hello, world!")
    end
  end

  describe ".perform_later" do
    it "schedules a job to be performed later" do
      expect(PulsarJob::Produce).to receive(:publish).with(job_class)
      job_class.perform_later
    end
  end

  describe "#subscription" do
    it "returns the default subscription" do
      expect(job.subscription).not_to be_nil
    end
  end

  describe "#topic" do
    it "returns the default topic" do
      expect(job.topic).to eq(PulsarJob.configuration.default_topic)
    end
  end

  describe "#payload_as_args?" do
    it "returns true if use_raw_payload is not true" do
      expect(job.payload_as_args?).to be true
    end
  end

  describe "#use_raw_payload" do
    it "returns false by default" do
      expect(job.use_raw_payload).to be false
    end
  end

  describe "#batched_consume?" do
    it "returns false by default" do
      expect(job.batched_consume?).to be false
    end
  end

  describe "#consumer_options" do
    it "returns a Pulsar::ConsumerConfiguration object" do
      expect(job.consumer_options).to be_a(Pulsar::ConsumerConfiguration)
    end
  end

  describe "#context_valid?" do
    it "returns true when the context is valid" do
      job.topic = "test_topic"
      job.subscription = "test_subscription"
      expect(job.context_valid?).to be true
    end
  end

  describe "private #auto_subscription" do
    it "returns a generated subscription string" do
      expect(job.send(:auto_subscription)).to match(/pulsar-job-subscription-.+/)
    end

    context "when socket is not defined" do
      before do
        # Simulate Socket not being defined
        Object.send(:remove_const, :Socket) if defined?(Socket)
      end

      after do
        # Restore Socket constant after the test
        Object.const_set("Socket", Module.new) unless defined?(Socket)
      end

      it "returns a subscription ID with a random host ID when Socket is not defined" do
        auto_subscription_result = job.send(:auto_subscription)
        expect(auto_subscription_result).to match(/^pulsar-job-subscription-[0-9a-f]{16}$/)
      end
    end
  end
end
