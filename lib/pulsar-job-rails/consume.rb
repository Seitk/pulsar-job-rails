# frozen_string_literal: true

require "pulsar/consumer"

module PulsarJob
  class Consume
    attr_reader :job, :client, :consumer, :listener, :is_running

    class InvalidJobConsumerOptionsError < StandardError; end
    class JobClassNotConfiguredError < StandardError; end
    class JobTopicNotFoundError < StandardError; end

    def initialize(job_class: nil, job: nil)
      if job_class.nil? && job.nil?
        raise JobClassNotConfiguredError.new("Job class not configured")
      end
      @job = job
      @job = job_class.new if job.nil?
    end

    def subscribe!
      if job.topic.nil? || job.subscription.nil?
        raise InvalidJobConsumerOptionsError.new("Job class #{job.class.name} must define topic and subscription. [topic=#{job.topic}][subscription=#{job.subscription}]")
      end

      begin
        @consumer = PulsarJob::Pools::Consumers.subscribe([job.topic], job.subscription, job.consumer_options)
        listen
      rescue Pulsar::Error::TopicNotFound
        raise JobTopicNotFoundError.new("Job topic #{job.topic} not found")
      rescue StandardError => ex
        raise ex
      end
    end

    def listen
      @listener ||= ::Pulsar::Consumer::ListenerToken.new
      while @listener.active?
        @is_running = true
        PulsarJob.logger.debug "Waiting for #{job.batched_consume? ? 'batched ' : ''}message..."
        begin
          msg = nil
          # Consumer receive will lock up the main thread, run in a new thread to handle gracefully shutdown
          Thread.new do
            begin
              if job.batched_consume?
                msg = consumer.batch_receive
              else
                msg = consumer.receive(PulsarJob.configuration.consumer_receive_timeout_millis)
              end
            rescue Pulsar::Error::AlreadyClosed
              @is_running = false
            rescue Pulsar::Error::Timeout
              # No message received, continue
              @is_running = false
            rescue StandardError => ex
              PulsarJob.logger.error "Error on polling consumer: #{ex.message}"
            end
          end.join

          handle(msg) if msg.present?

          if PulsarJob.configuration.consumer_receive_internal_millis > 0
            sleep(PulsarJob.configuration.consumer_receive_internal_millis / 1000.0)
          end
        rescue StandardError => ex
          PulsarJob.logger.error "Error on listening message: #{ex.message}"
        rescue Pulsar::Error::AlreadyClosed
          @is_running = false
        ensure
          @is_running = false
        end
      end
      @is_running = false
    end

    def handle(msg)
      # Reset the job instance
      job.run_callbacks(:perform) do
        begin
          PulsarJob.logger.debug "Message received: #{job.inspect}\##{job._method.inspect}. Payload: #{msg.inspect}"
          handle_with_job_error_handler(msg)
          PulsarJob.logger.debug "Message handled successfully"

          # FIXME
          if job.batched_consume?
            msg.to_a.each do |m|
              consumer.acknowledge(m)
            end
          else
            consumer.acknowledge(msg)
          end
        rescue Exception => ex
          PulsarJob.logger.error "Error while handling message: #{ex.inspect} | #{ex.backtrace.join("\n")}"

          # Interface mismatch, move to DLQ
          # TODO: Move to DLQ right away
          if ex.is_a? ArgumentError
            if job.batched_consume?
              msg.to_a.each do |m|
                consumer.acknowledge(m)
              end
            else
              consumer.acknowledge(msg)
            end
          else
            # Automatically nack messages that fail
            # TODO: Move to adapter
            if job.batched_consume?
              msg.to_a.each do |m|
                consumer.negative_acknowledge(m)
              end
            else
              consumer.negative_acknowledge(msg)
            end
          end
        end
      end
    rescue StandardError => ex
      PulsarJob.logger.error "Internal error on handling pulsar message: #{ex.message} | #{ex.backtrace.join("\n")}"
    end

    def handle_with_job_error_handler(msg)
      handler = job._method.to_sym

      if job.batched_consume?
        job.result = job.send(handler, msg.to_a.map { |m| process_payload(m) } )
        return
      end
      
      # Single message
      payload = process_payload(msg)
      job.payload = payload
      if job.payload_as_args?
        # Enqueuing jobs with method arguments, hash keys are ignored
        args = payload.try(:[], 'args')
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
    rescue StandardError => ex
      job.rescue_with_handler(ex)
    ensure
      job.reset_job_context
    end

    def shutdown
      @listener.finish
      count = 0
      while @is_running
        if count > PulsarJob.configuration.max_shutdown_wait_seconds
          PulsarJob.logger.error "Timeout for #{job.class.name} to finish, aborting"
          break
        end
        PulsarJob.logger.debug "Waiting for job to finish..."
        sleep 1
        count += 1
      end
      consumer.close
      PulsarJob.logger.debug "Pulsar consumer closed"
    end

    private

    def process_payload(msg)
      data = JSON.parse(msg.data) rescue nil
      data || msg.data
    end
  end
end
