# frozen_string_literal: true

module PulsarJob
  module Consumes
    class One < Base
      attr_accessor :job, :msg

      def initialize(job)
        @job = job
        @msg = nil
      end

      def receive
        @msg = consumer.receive(PulsarJob.configuration.consumer_receive_timeout_millis)
      end

      def raw_payload
        msg
      end

      def acknowledge
        consumer.acknowledge(msg)
      end

      def negative_acknowledge
        consumer.negative_acknowledge(msg)
      end

      def execute(handler)
        payload = process_payload(msg)
        job.payload = payload
        if job.payload_as_args?
          # Enqueuing jobs with method arguments, hash keys are ignored
          args = payload.try(:[], "args")
          args = args.values if args.is_a?(Hash)
          job.args = args
          job.result = job.send(handler, *args)
        else
          job.result = job.send(handler, {
            payload: payload,
            message_id: msg.message_id,
            raw: msg,
          })
        end
      end

      def redelivery_count
        msg&.redelivery_count || 0
      end

      def send_to_dlq
        # if DLQ is not set, pass to negative_acknowledge
        return false unless job.dlq_topic.present?

        # Send using raw data of message
        producer = ::PulsarJob::Produce.new(job: job)
        producer.publish_raw!(msg.data)
      end
    end
  end
end
