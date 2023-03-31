require "spec_helper"

RSpec.describe PulsarJob::Consumes::Base do
  class MockConsumesAdapter < PulsarJob::Consumes::Base
    def acknowledge; end
    def negative_acknowledge; end
    def execute(handler); end

    def redelivery_count
      0
    end

    def raw_payload
      {}
    end
  end

  class MockConsumesJob < PulsarJob::Base
  end

  let(:base_instance) { MockConsumesAdapter.new }
  let(:job) { MockConsumesJob.new }
  let(:raw_payload) { { some_key: "some_value" }.to_json }
  let(:handler) { :custom_handler }
  let(:msg) { instance_double("Pulsar::Message", data: raw_payload) }

  before do
    allow(base_instance).to receive(:job).and_return(job)
    allow(base_instance).to receive(:raw_payload).and_return(raw_payload)
    allow(job).to receive(:_method).and_return(handler)
    allow(job).to receive(:reset_job_context)
  end

  describe "#handle" do
    it "calls handle_with_job_error_handler and acknowledge" do
      expect(base_instance).to receive(:handle_with_job_error_handler)
      expect(base_instance).to receive(:acknowledge)
      base_instance.handle
    end

    it "calls on_error when an exception is raised" do
      expect(base_instance).to receive(:handle_with_job_error_handler).and_raise(StandardError)
      expect(base_instance).to receive(:on_error).with(kind_of(StandardError))
      base_instance.handle
    end
  end

  describe "#on_error" do
    it "logs the error and calls negative_acknowledge for unexpected errors" do
      error = StandardError.new
      allow(base_instance).to receive(:redelivery_count).and_return(0)
      expect(base_instance).to receive(:negative_acknowledge)
      base_instance.on_error(error)
    end

    context "when the error is an ArgumentError or redelivery_count is greater than or equal to 1" do
      it "calls send_to_dlq and acknowledge if send_to_dlq is successful" do
        error = ArgumentError.new
        allow(base_instance).to receive(:redelivery_count).and_return(1)
        expect(base_instance).to receive(:send_to_dlq).and_return(true)
        expect(base_instance).to receive(:acknowledge)
        base_instance.on_error(error)
      end
    end
  end

  describe "#handle_with_job_error_handler" do
    it "logs the received message, calls execute with the handler, and logs successful handling" do
      expect(PulsarJob.logger).to receive(:debug).with(kind_of(String)).twice
      expect(base_instance).to receive(:execute).with(handler)
      base_instance.handle_with_job_error_handler
    end

    it "calls job.rescue_with_handler when an exception is raised" do
      error = StandardError.new
      expect(base_instance).to receive(:execute).with(handler).and_raise(error)
      expect(job).to receive(:rescue_with_handler).with(error)
      base_instance.handle_with_job_error_handler
    end
  end

  describe "#process_payload" do
    it "returns the parsed JSON payload if successful" do
      expect(base_instance.process_payload(msg)).to eq(JSON.parse(raw_payload))
    end

    it "returns the raw payload data when JSON parsing fails" do
      bad_payload = "not a json string"
      allow(msg).to receive(:data).and_return(bad_payload)
      expect(base_instance.process_payload(msg)).to eq(bad_payload)
    end
  end
end
