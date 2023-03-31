# frozen_string_literal: true

module PulsarJob
  module Consumes
    class Base
      attr_accessor :job, :consumer

      def handle
        # Reset the job instance
        job.raw = raw_payload
        job.run_callbacks(:perform) do
          begin
            handle_with_job_error_handler
            acknowledge()
          rescue SystemExit => ex
            raise ex
          rescue Exception => ex
            on_error(ex)
          end
        end
      rescue SystemExit => ex
        raise ex
      rescue StandardError => ex
        PulsarJob.logger.error "Internal error on handling pulsar message: #{ex.message} | #{ex.backtrace.join("\n")}"
      end

      def on_error(ex)
        # Interface mismatch, move to DLQ
        if ex.is_a? ArgumentError || redelivery_count >= job.max_redelivery_count
          # Send the message to another DLQ topic
          # Automatically nack messages that fail
          if send_to_dlq()
            PulsarJob.logger.info "Message sent to DLQ: #{job.inspect}\##{job._method.inspect}. Payload: #{raw_payload.inspect}"
            acknowledge()
            return
          end
        end

        # Automatically nack messages that fail
        negative_acknowledge()
      end

      def handle_with_job_error_handler
        PulsarJob.logger.debug "Message received: #{job.inspect}\##{job._method.inspect}. Payload: #{raw_payload.inspect}"
        handler = job._method.to_sym
        execute(handler)
        PulsarJob.logger.debug "Message handled successfully"
      rescue StandardError => ex
        job.rescue_with_handler(ex)
      ensure
        job.reset_job_context
      end

      def process_payload(msg)
        data = JSON.parse(msg.data) rescue nil
        data || msg.data
      end

      # Expect subclasses to implement the following methods

      def raw_payload
        fail NotImplementedError
      end

      def redelivery_count
        fail NotImplementedError
      end

      def acknowledge
        fail NotImplementedError
      end

      def negative_acknowledge
        fail NotImplementedError
      end

      def send_to_dlq
        fail NotImplementedError
      end

      def execute(handler)
        fail NotImplementedError
      end
    end
  end
end