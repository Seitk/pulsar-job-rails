require "spec_helper"

RSpec.describe PulsarJob::CLI do
  let(:args) { [] }
  subject(:cli) { described_class.new(args) }

  describe "OPTIONS constant" do
    it "contains the expected command line options" do
      expect(PulsarJob::CLI::OPTIONS).to include(
        data: a_hash_including(command: "-d", description: a_string_matching(/JSON string format/)),
        topic: a_hash_including(command: "-t", description: a_string_matching(/YourModel.async.some_method/)),
        subscription: a_hash_including(command: "-s", description: a_string_matching(/YourModel.async.some_method/)),
      )
    end
  end

  describe "OptionParser" do
    it "parses the data option" do
      args << "-d" << '{"foo":"bar"}'
      expect(cli.data).to eq("foo" => "bar")
    end

    it "parses the topic option" do
      args << "-t" << "test_topic"
      expect(cli.topic).to eq("test_topic")
    end

    it "parses the subscription option" do
      args << "-s" << "test_subscription"
      expect(cli.subscription).to eq("test_subscription")
    end

    context "when given invalid options" do
      it "raises an error for invalid JSON data" do
        args << "-d" << "{invalid_json}"
        expect { cli }.to raise_error(JSON::ParserError)
      end

      it "raises an error for unrecognized options" do
        args << "--unknown-option"
        expect { cli }.to raise_error(OptionParser::InvalidOption)
      end
    end

    context "when --help or -h option is given" do
      before do
        allow_any_instance_of(OptionParser).to receive(:puts)
        allow_any_instance_of(OptionParser).to receive(:exit)
      end

      it "displays help message and exits for --help option" do
        args << "--help"
        expect_any_instance_of(OptionParser).to receive(:puts)
        expect_any_instance_of(OptionParser).to receive(:exit).with(0)
        cli
      end

      it "displays help message and exits for -h option" do
        args << "-h"
        expect_any_instance_of(OptionParser).to receive(:puts)
        expect_any_instance_of(OptionParser).to receive(:exit).with(0)
        cli
      end
    end
  end
end
