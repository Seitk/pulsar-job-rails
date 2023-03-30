require "spec_helper"

RSpec.describe PulsarJob::Hooks::Callbacks do
  class TestJob
    include PulsarJob::Hooks::Callbacks
  end

  let(:test_job) { TestJob.new }

  describe "ClassMethods" do
    describe ".before_perform" do
      it "sets a before_perform callback" do
        expect {
          TestJob.before_perform { "before_perform" }
        }.to change { TestJob.__callbacks[:perform].select { |cb| cb.kind == :before }.count }.by(1)
      end
    end

    describe ".after_perform" do
      it "sets an after_perform callback" do
        expect {
          TestJob.after_perform { "after_perform" }
        }.to change { TestJob.__callbacks[:perform].select { |cb| cb.kind == :after }.count }.by(1)
      end
    end

    describe ".before_enqueue" do
      it "sets a before_enqueue callback" do
        expect {
          TestJob.before_enqueue { "before_enqueue" }
        }.to change { TestJob.__callbacks[:enqueue].select { |cb| cb.kind == :before }.count }.by(1)
      end
    end

    describe ".after_enqueue" do
      it "sets an after_enqueue callback" do
        expect {
          TestJob.after_enqueue { "after_enqueue" }
        }.to change { TestJob.__callbacks[:enqueue].select { |cb| cb.kind == :after }.count }.by(1)
      end
    end
  end

  describe "Callbacks execution" do
    before do
      TestJob.before_perform { |job| job.instance_variable_set(:@before_perform, true) }
      TestJob.after_perform { |job| job.instance_variable_set(:@after_perform, true) }
      TestJob.before_enqueue { |job| job.instance_variable_set(:@before_enqueue, true) }
      TestJob.after_enqueue { |job| job.instance_variable_set(:@after_enqueue, true) }
    end

    it "executes before_perform and after_perform callbacks" do
      test_job.run_callbacks(:perform)
      expect(test_job.instance_variable_get(:@before_perform)).to be_truthy
      expect(test_job.instance_variable_get(:@after_perform)).to be_truthy
    end

    it "executes before_enqueue and after_enqueue callbacks" do
      test_job.run_callbacks(:enqueue)
      expect(test_job.instance_variable_get(:@before_enqueue)).to be_truthy
      expect(test_job.instance_variable_get(:@after_enqueue)).to be_truthy
    end
  end
end
