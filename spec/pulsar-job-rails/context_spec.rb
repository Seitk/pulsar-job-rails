require "spec_helper"

RSpec.describe PulsarJob::Context do
  class MockContextClass
    include PulsarJob::Context
  end

  let(:dummy_class) { MockContextClass }
  subject(:dummy_instance) { MockContextClass.new }

  describe "#reset_job_context" do
    it "resets context variables" do
      dummy_instance.instance_variable_set(:@args, ["arg1", "arg2"])
      dummy_instance.instance_variable_set(:@payload, { key: "value" })
      dummy_instance.instance_variable_set(:@created_at, Time.now)
      dummy_instance.instance_variable_set(:@result, "result")

      expect(dummy_instance.instance_variable_get(:@args)).to_not be_nil
      expect(dummy_instance.instance_variable_get(:@payload)).to_not be_nil
      expect(dummy_instance.instance_variable_get(:@created_at)).to_not be_nil
      expect(dummy_instance.instance_variable_get(:@result)).to_not be_nil

      dummy_instance.reset_job_context
      expect(dummy_instance.instance_variable_get(:@args)).to be_nil
      expect(dummy_instance.instance_variable_get(:@payload)).to be_nil
      expect(dummy_instance.instance_variable_get(:@created_at)).to be_nil
      expect(dummy_instance.instance_variable_get(:@result)).to be_nil
    end
  end

  # describe "#subscription" do
  #   context "when subscription is set" do
  #     before { dummy_instance.subscription = "custom_subscription" }

  #     it "returns the custom subscription" do
  #       expect(dummy_instance.subscription).to eq("custom_subscription")
  #     end
  #   end

  #   context "when subscription is not set" do
  #     context "when default subscription is configured" do
  #       before { allow(PulsarJob.configuration).to receive(:default_subscription).and_return("default_subscription") }
  #       it "returns the default subscription from configuration" do
  #         expect(dummy_instance.subscription).to eq("default_subscription")
  #       end
  #     end

  #     context "when default subscription is not configured" do
  #       before { allow(PulsarJob.configuration).to receive(:default_subscription).and_return(nil) }

  #       it "returns an auto-generated subscription" do
  #         expect(dummy_instance.subscription).to match(/pulsar-job-subscription-.*/)
  #       end
  #     end
  #   end
  # end

  # describe "#topic" do
  #   context "when topic is set" do
  #     before { dummy_instance.topic = "custom_topic" }
  #     it "returns the custom topic" do
  #       expect(dummy_instance.topic).to eq("custom_topic")
  #     end
  #   end

  #   context "when topic is not set and default topic is configured" do
  #     before { allow(PulsarJob.configuration).to receive(:default_topic).and_return("default_topic") }

  #     it "returns the default topic from configuration" do
  #       expect(dummy_instance.topic).to eq("default_topic")
  #     end
  #   end
  # end

  # describe "#context_valid?" do
  #   context "when subscription and topic are set" do
  #     before do
  #       dummy_instance.subscription = "custom_subscription"
  #       dummy_instance.topic = "custom_topic"
  #     end
  #     it "returns true" do
  #       expect(dummy_instance.context_valid?).to be true
  #     end
  #   end

  #   context "when either subscription or topic is not set" do
  #     before { dummy_instance.subscription = "custom_subscription" }

  #     it "returns false" do
  #       expect(dummy_instance.context_valid?).to be false
  #     end
  #   end
  # end

  # describe "#auto_subscription" do
  #   context "when Socket.gethostname is available" do
  #     before { allow(Socket).to receive(:gethostname).and_return("test_hostname") }
  #     it "returns a subscription based on the hostname" do
  #       expect(dummy_instance.send(:auto_subscription)).to eq("pulsar-job-subscription-test_hostname")
  #     end
  #   end

  #   context "when Socket.gethostname is not available" do
  #     before do
  #       hide_const("Socket")
  #       allow(SecureRandom).to receive(:hex).with(8).and_return("random_hex")
  #     end

  #     it "returns a subscription based on a random hex value" do
  #       expect(dummy_instance.send(:auto_subscription)).to eq("pulsar-job-subscription-random_hex")
  #     end
  #   end
  # end
end
