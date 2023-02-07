# frozen_string_literal: true

require "optparse"
require "active_support/inflector"

module PulsarJob
  class CLI
    class << self
      def main(args)
        new(args).run
      end
    end

    attr_reader :job_name, :data, :class, :topic, :subscription

    OPTIONS = {
      job: {
        command: "-j",
        description: "The job class to run, e.g. SampleJob",
      },
      data: {
        command: "-d",
        description: "The data to produce with the job message in JSON string format. e.g. '{\"foo\": \"bar\"}'",
      },
      class: {
        command: "-c",
        description: "The class to run as consumer handler, e.g. . Remark: only used with Class.async call. e.g. YourModel.async.some_method",
      },
      topic: {
        command: "-t",
        description: "The topic to consume from, only used with Class.async call. e.g. YourModel.async.some_method",
      },
      subscription: {
        command: "-s",
        description: "The subscription name of consumes, only used with Class.async call. e.g. YourModel.async.some_method",
      },
    }.freeze  

    def initialize(args)
      @parser = build_parser
      @parser.parse!(args)
    end

    private

    def build_parser
      OptionParser.new do |opts|
        opts.banner = "Usage: pulsar_job [options]"
        opts.on_tail("-h", "--help", "Show this message") do
          puts opts
          exit 0
        end

        OPTIONS.each do |name, option|
          opt_name = "--#{name.to_s.gsub('_', '-')} #{name}"

          description = option[:description] || "N/A"
          if option[:default]
            description += " (default: #{option[:default]})"
          end
          
          opts.on(opt_name, description) do |value|
            load_option_value(name, option, value)
          end
        end
      end
    end

    def load_option_value(name, option, value)
      case name
      when :job
        @job_name = value.to_s.underscore
      when :class
        @class = value.to_s.underscore
      when :topic, :subscription
        instance_variable_set("@#{name}", value)
      when :data
        @data = JSON.parse(value)
      end
    end
  end
end
