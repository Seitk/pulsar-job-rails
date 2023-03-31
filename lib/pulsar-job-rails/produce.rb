# frozen_string_literal: true

require "pulsar/producer"

module PulsarJob
  class Produce
    attr_accessor :job, :producer

    class JobClassNotDefinedError < StandardError; end

    class << self
      def publish(job, *args)
        ::PulsarJob::Produce.new(job: job).publish!({
          job: job.class.name,
          method: job._method,
          args: args,
        })
      end
    end

    def initialize(job_class: nil, job: nil)
      # TODO: Decouple the job class for model async call
      @job = job
      if @job.nil? && job_class.present?
        @job = job_class.new
      end
      raise JobClassNotDefinedError.new("Job class is not defined") if @job.nil?
      @producer = PulsarJob::Pools::Producers.get(@job.topic) do |raw_producer|
        self
      end
    end

    def publish!(payload)
      payload ||= {
        job: job.class.name,
        method: job._method,
        args: (job.args || {}),
      }
      payload[:sent_at] = DateTime.now.to_s
      @producer.send(payload.to_json, {
 # deliver_after: 5 * 1000
        })
    end

    def shutdown
      @producer.close if @producer.present?
    end

    def publish_raw!(payload)
      @producer.send(payload, {})
    end
  end
end
