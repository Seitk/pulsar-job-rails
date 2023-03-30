require "spec_helper"
require "active_support/core_ext/hash/indifferent_access"

RSpec.describe PulsarJob::Async::Wrapper do
  class TestClass
    def self.find(*args); end
    def self.dummy_static_method(*args); end

    def id; end
    def dummy_instance_method(*args); end
  end

  let(:test_klass) { TestClass }
  let(:test_method) { :dummy_instance_method }
  let(:test_args) { [1, 2, 3] }
  let(:instance) { TestClass.new }

  subject { described_class.new(test_klass) }

  describe "#initialize" do
    it "initializes with the given klass" do
      expect(subject.klass).to eq(test_klass)
      expect(subject.instance).to be_nil
    end
  end

  describe "#set" do
    it "sets instance variable using hash key and values" do
      subject.set(instance: instance)

      expect(subject.instance).to eq(instance)
    end
  end

  describe "#perform" do
    context "when instance is present" do
      it "calls the method on the instance with provided arguments" do
        allow(test_klass).to receive(:find).and_return(instance)
        expect(instance).to receive(:id).and_return(1)
        expect(instance).to receive(test_method).with(*test_args)
        subject.perform(payload: { klass: "TestClass", id: instance.id, method: test_method, args: test_args }.with_indifferent_access, message_id: 1, raw: nil)
      end
    end

    context "when instance is not present" do
      let(:test_method) { :dummy_static_method }
      it "calls the method on the class with provided arguments" do
        allow(test_klass).to receive(:find).and_return(instance)
        expect(test_klass).to receive(test_method).with(*test_args)
        subject.perform(payload: { klass: "TestClass", method: test_method, args: test_args }.with_indifferent_access, message_id: 1, raw: nil)
      end
    end

    context "when class is invalid" do
      it "raises an AsyncInvalidContextError" do
        expect {
          subject.perform(payload: { klass: "InvalidClass", method: "test_method", args: test_args }.with_indifferent_access, message_id: 1, raw: nil)
        }.to raise_error(PulsarJob::Async::Wrapper::AsyncInvalidContextError, /Async execution failed, class InvalidClass is invalid. uninitialized constant InvalidClass/)
      end
    end
  end

  describe "#method_missing" do
    let(:producer) { instance_double(PulsarJob::Produce) }
    let(:test_method) { :dummy_static_method }

    it "enqueues the method and args when a missing method is called" do
      expect(PulsarJob::Produce).to receive(:new).with(job: subject).and_return(producer)
      expect(subject).to receive(:context_valid?).and_return(true)
      expect(producer).to receive(:publish!).with(klass: "TestClass", method: test_method, args: test_args)
      subject.send(test_method, *test_args)
    end

    context "with instance" do
      class WrapperTestClass
        include PulsarJob::Asyncable

        def id
          1
        end

        def dummy_instance_method; end
      end

      let(:test_klass) { WrapperTestClass }
      let(:test_instance) { test_klass.new }
      let(:test_method) { :dummy_instance_method }
      it "enqueues with instance id" do
        expect(PulsarJob::Produce).to receive(:new).and_return(producer)
        expect(producer).to receive(:publish!).with(klass: test_klass.to_s, id: test_instance.id, method: test_method, args: test_args)
        wrapper = test_instance.async
        expect(wrapper).to receive(:context_valid?).and_return(true)
        wrapper.send(test_method, *test_args)
      end
    end
  end
end
