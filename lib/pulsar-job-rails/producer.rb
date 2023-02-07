# frozen_string_literal: true

require "pulsar/consumer"

module PulsarJob
  class Producer
    attr_accessor :job, :producer

    class JobClassNotDefinedError < StandardError; end
    class << self
      def publish(job, *args)
        ::PulsarJob::Producer.new(job).publish!({
          job: job.class.name,
          method: job.method,
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
      @producer = PulsarJob::Client.instance.create_producer(job.topic, producer_options)
    end

    def producer_options
      options = Pulsar::ProducerConfiguration.new
      options.send_timeout_millis = 3000 # 3 seconds timeout on connecting producer
      options.producer_name = producer_name
      options
    end

    def producer_name
      host_id =
        if defined?(Socket)
          Socket.gethostname
        else
          SecureRandom.hex(8)
        end
      "pulsar-job-producer-#{host_id}"
    end

    def publish!(payload)
      payload ||= {
        job: job.class.name,
        method: job.method,
        args: (job.args || {}),
      }
      payload[:sent_at] = DateTime.now.to_s
      producer.send(payload.to_json, {
        # deliver_after: 5 * 1000
      })
    end

    def shutdown
      producer.close
      PulsarJob.logger.debug "Pulsar producer closed"
    end
  end
end
