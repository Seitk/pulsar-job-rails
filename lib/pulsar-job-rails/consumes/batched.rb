# frozen_string_literal: true

module PulsarJob
  module Consumes
    class Batched < Base
      attr_accessor :job, :msgs

      def initialize(job)
        @job = job
        @msgs = []
      end

      def receive
        # Aware that Pulsar::Messages#to_a seems can only be called once
        @msgs = consumer.batch_receive.to_a
      end

      def raw_payload
        msgs
      end

      def acknowledge
        msgs.to_a.each { |m| consumer.acknowledge(m) }
      end

      def negative_acknowledge
        msgs.to_a.each { |m| consumer.negative_acknowledge(m) }
      end

      def execute(handler)
        job.result = job.send(handler, msgs.to_a.map { |m| process_payload(m) })
      end

      def redelivery_count
        msgs.to_a.map { |m|
          m.redelivery_count
        }.max || 0
      end

      def send_to_dlq
        # if DLQ is not set, pass to negative_acknowledge
        return false unless job.dlq_topic.present?

        producer = ::PulsarJob::Produce.new(job: job)
        msgs.to_a.each do |m|
          producer.publish_raw!(m.data)
        end
      end
    end
  end
end
