# frozen_string_literal: true

require "pulsar/consumer"

module PulsarJob
  class Producer
    attr_accessor :job, :producer

    class << self
      def publish(job, *args)
        ::PulsarJob::Producer.new(job).publish!(args)
      end
    end

    def initialize(job_class)
      @job = job_class.new
      @producer = PulsarJob::Client.instance.create_producer(job.topic, producer_options)
    end

    def producer_options
      options = Pulsar::ProducerConfiguration.new
      options.send_timeout_millis = 3000
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

    def publish!(data)
      payload = {
        job: job.class.name,
        method: job.method,
        args: (data || job.args || {}),
      }
      payload[:sent_at] = DateTime.now.to_s
      producer.send(payload.to_json, {
        deliver_after: 5 * 1000
      })
    end

    def shutdown
      producer.close
      PulsarJob.logger.debug "Pulsar producer closed"
    end
  end
end
