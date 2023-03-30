require "spec_helper"

RSpec.describe PulsarJob do
  describe "VERSION" do
    it "has a version number" do
      expect(PulsarJob::VERSION).not_to be_nil
      expect(PulsarJob::VERSION).to be_instance_of(String)
    end
  end
end
