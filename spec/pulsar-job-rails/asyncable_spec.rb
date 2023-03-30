require "spec_helper"

RSpec.describe PulsarJob::Asyncable do
  class DummyClass
    include PulsarJob::Asyncable

    def instance_method(*args)
      "Instance method called with: #{args.inspect}"
    end

    def self.class_method(*args)
      "Class method called with: #{args.inspect}"
    end
  end

  let(:dummy) { DummyClass.new }

  describe ".wrap" do
    context "when wrapping an instance method" do
      before do
        PulsarJob::Asyncable.wrap(DummyClass, :instance_method)
      end

      it "redefines the method to enqueue a job" do
        expect_any_instance_of(PulsarJob::Async::Wrapper).to receive(:enqueue).with(:instance_method, [42])
        dummy.instance_method(42)
      end
    end

    context "when wrapping a class method" do
      before do
        PulsarJob::Asyncable.wrap(DummyClass, :class_method)
      end

      it "redefines the method to enqueue a job" do
        expect_any_instance_of(PulsarJob::Async::Wrapper).to receive(:enqueue).with(:class_method, [42])
        DummyClass.class_method(42)
      end
    end
  end

  describe "#async" do
    it "returns a PulsarJob::Async::Wrapper instance" do
      expect(dummy.async).to be_a(PulsarJob::Async::Wrapper)
    end

    it "sets the wrapper instance to the current instance" do
      expect(dummy.async.instance).to eq(dummy)
    end
  end

  describe ".async" do
    it "returns a PulsarJob::Async::Wrapper instance" do
      expect(DummyClass.async).to be_a(PulsarJob::Async::Wrapper)
    end

    it "sets the wrapper instance to the current class" do
      expect(DummyClass.async.klass).to eq(DummyClass)
    end
  end
end
