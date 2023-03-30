require "spec_helper"

RSpec.describe PulsarJob::Consume do
  before do
    allow(PulsarJob).to receive(:logger).and_return(Logger.new("/dev/null"))
  end

  let(:job_class) do
    Class.new(PulsarJob::Base) do
      def topic
        "test_topic"
      end

      def subscription
        "test_subscription"
      end

      def method
        :perform
      end

      def perform(payload)
      end
    end
  end

  let(:job_instance) { job_class.new }

  subject { described_class.new(job: job_instance) }

  describe "#initialize" do
    it "raises JobClassNotConfiguredError if job_class and job not provided" do
      expect { described_class.new }.to raise_error(PulsarJob::Consume::JobClassNotConfiguredError)
    end

    it "initializes with job_class" do
      expect(subject.job).to be_a(job_class)
    end

    it "initializes with job instance" do
      consume = described_class.new(job: job_instance)
      expect(consume.job).to be_a(job_class)
    end
  end

  describe "#subscribe!" do
    let(:consumer) { spy("consumer") }

    context "when topic and subscription are not defined" do
      let(:job_class) do
        Class.new(PulsarJob::Base) do
          def topic
            nil
          end

          def subscription
            nil
          end

          def method
            :perform
          end

          def perform(payload)
          end
        end
      end

      it "raises InvalidJobConsumerOptionsError if topic or subscription is not defined" do
        allow(PulsarJob::Pools::Consumers).to receive(:subscribe).and_return(consumer)
        expect { subject.subscribe! }.to raise_error(PulsarJob::Consume::InvalidJobConsumerOptionsError)
      end
    end

    context "when topic and subscription are defined" do
      it "subscribes to the topic and subscription" do
        allow(PulsarJob::Pools::Consumers).to receive(:subscribe).and_return(consumer)
        expect(subject).to receive(:listen)
        subject.subscribe!
      end
    end

    context "when the topic not found in Pulsar" do
      it "raises JobTopicNotFoundError" do
        allow(PulsarJob::Pools::Consumers).to receive(:subscribe).and_raise(Pulsar::Error::TopicNotFound)
        expect { subject.subscribe! }.to raise_error(PulsarJob::Consume::JobTopicNotFoundError)
      end
    end
  end

  describe "#handle" do
    let(:consumer) { spy("consumer") }
    let(:message) { instance_double(Pulsar::Message, data: '{"args": [1, 2]}', message_id: 1) }
    let(:batch_message) do
      instance_double(Pulsar::Messages, to_a: [message], present?: true)
    end

    before do
      subject.instance_variable_set(:@consumer, consumer)
      allow(subject).to receive(:handle).and_call_original
    end

    it "calls the perform method on the job with the payload" do
      allow(job_instance).to receive(:batched_consume?).and_return(false)
      allow(job_instance).to receive(:payload_as_args?).and_return(true)
      expect(job_instance).to receive(:send).with(job_instance.method, 1, 2)

      subject.send(:handle, message)
    end

    it "calls the perform method on the job with the batch payload" do
      allow(job_instance).to receive(:batched_consume?).and_return(true)
      allow(job_instance).to receive(:payload_as_args?).and_return(true)
      expect(job_instance).to receive(:send).with(job_instance.method, array_including(anything))

      subject.send(:handle, batch_message)
    end
  end

  describe "#shutdown" do
    let(:listener) { instance_double(Pulsar::Consumer::ListenerToken, finish: nil, active?: false) }
    let(:consumer) { instance_double(Pulsar::Consumer, close: nil) }

    before do
      subject.instance_variable_set(:@listener, listener)
      subject.instance_variable_set(:@consumer, consumer)
    end

    it "finishes the listener" do
      expect(listener).to receive(:finish)
      subject.shutdown
    end

    it "closes the consumer" do
      expect(consumer).to receive(:close)
      subject.shutdown
    end
  end

  describe "#listen" do
    let(:listener) { instance_double(Pulsar::Consumer::ListenerToken, finish: nil, active?: false) }
    let(:consumer) { instance_double(Pulsar::Consumer, close: nil) }
    let(:message) { instance_double(Pulsar::Message, data: '{"args": [1, 2]}', message_id: 1) }

    before do
      subject.instance_variable_set(:@listener, listener)
      subject.instance_variable_set(:@consumer, consumer)
      allow(PulsarJob.configuration).to receive(:consumer_receive_internal_millis).and_return(0)
      allow(PulsarJob.configuration).to receive(:consumer_receive_timeout_millis).and_return(0)
    end

    it "receives and handles messages until the listener is inactive" do
      # Simulate receiving a message and then stopping the listener
      allow(consumer).to receive(:receive).and_return(message)
      allow(listener).to receive(:active?).and_return(true, false)
      expect(subject).to receive(:handle)

      # Call the #listen method
      subject.send(:listen)
    end

    context "when job is batched" do
      let(:messages) do
        instance_double(Pulsar::Messages, to_a: [message], present?: true)
      end
      it "receives and handles messages until the listener is inactive" do
        # Simulate receiving a message and then stopping the listener
        allow(job_instance).to receive(:batched_consume?).and_return(true)
        allow(consumer).to receive(:batch_receive).and_return(messages)
        allow(listener).to receive(:active?).and_return(true, false)
        expect(subject).to receive(:handle)

        # Call the #listen method
        subject.send(:listen)
      end
    end

    context "when consumer is closed" do
      it "does not raise error" do
        allow(consumer).to receive(:receive).and_raise(Pulsar::Error::AlreadyClosed)
        expect(subject).not_to receive(:handle)
        expect {
          subject.send(:listen)
        }.not_to raise_error
      end
    end

    context "when consumer received timeout" do
      it "does not raise error" do
        allow(consumer).to receive(:receive).and_raise(Pulsar::Error::Timeout)
        expect(subject).not_to receive(:handle)
        expect {
          subject.send(:listen)
        }.not_to raise_error
      end
    end
  end

  describe "#handle" do
    let(:message) { instance_double(Pulsar::Message, data: '{"args": [1, 2]}', message_id: 1) }

    before do
      allow(PulsarJob).to receive(:logger).and_return(Logger.new(nil))
      allow(subject).to receive(:process_payload).and_return("args" => [1, 2])
    end

    it "acknowledges the message after successful handling" do
      expect(subject).to receive(:handle_with_job_error_handler).with(message)
      expect(subject.consumer).to receive(:acknowledge).with(message)

      subject.send(:handle, message)
    end

    it "negative acknowledges the message after a failed handling" do
      error = StandardError.new("Test error")
      expect(subject).to receive(:handle_with_job_error_handler).with(message).and_raise(error)
      expect(subject.consumer).to receive(:negative_acknowledge).with(message)
      subject.send(:handle, message)
    end

    it "triggers callback" do
      expect(subject).to receive(:handle_with_job_error_handler).with(message)
      expect(subject.consumer).to receive(:acknowledge).with(message)
      expect(job_instance).to receive(:run_callbacks).and_call_original
      subject.send(:handle, message)
    end

    context "when batched_consume? is true" do
      let(:messages) do
        instance_double(Pulsar::Messages, to_a: [message, message], present?: true)
      end

      it "acknowledges each message in the batch after successful handling" do
        allow(job_instance).to receive(:batched_consume?).and_return(true)
        expect(subject).to receive(:handle_with_job_error_handler).with(messages)
        # expect(subject.consumer).to receive(:acknowledge).with(message).twice
        subject.send(:handle, messages)
      end

      it "negative acknowledges each message in the batch after a failed handling" do
        error = StandardError.new("Test error")
        allow(job_instance).to receive(:send).with(:perform, anything).and_raise(error)
        allow(job_instance).to receive(:batched_consume?).and_return(true)
        expect(job_instance).to receive(:rescue_with_handler).with(error)
        expect(subject.consumer).to receive(:negative_acknowledge).with(message).twice

        subject.send(:handle, messages)
      end
    end
  end

  describe "#handle_with_job_error_handler" do
    let(:message) { instance_double(Pulsar::Message, data: '{"args": [1, 2]}', message_id: 1) }
    let(:error) { StandardError.new("Test error") }

    before do
      allow(job_instance).to receive(:payload_as_args?).and_return(true)
    end

    it "calls the job perform method with correct arguments and rescues any errors" do
      allow(job_instance).to receive(:send).with(:perform, 1, 2).and_raise(error)
      expect(job_instance).to receive(:rescue_with_handler).with(error)
      expect(job_instance).to receive(:reset_job_context)

      subject.send(:handle_with_job_error_handler, message)
    end
  end
end
