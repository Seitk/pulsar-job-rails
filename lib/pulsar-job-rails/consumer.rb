# frozen_string_literal: true

require "pulsar/consumer"

module PulsarJob
  class Consumer
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
        raise InvalidJobConsumerOptionsError.new("Job class #{job.class.name} must define topic and subscription")
      end

      begin
        @consumer = PulsarJob::Client.instance.subscribe([job.topic], job.subscription, {
          consumer_type: job.consumer_type,
        })
        listen
      rescue Pulsar::Error::TopicNotFound
        raise JobTopicNotFoundError.new("Job topic #{job.topic} not found")
      rescue StandardError => ex
        raise ex
      end
    end

    def listen
      @listener = ::Pulsar::Consumer::ListenerToken.new
      while @listener.active?
        @is_running = true
        PulsarJob.logger.debug "Waiting for message..."
        begin
          msg = nil
          # Consumer receive will lock up the main thread, run in a new thread to handle gracefully shutdown
          Thread.new do
            begin
              msg = consumer.receive(5000)
              # PulsarJob.logger.debug "======== Message received: #{msg.redelivery_count}"
            rescue Pulsar::Error::Timeout
              # No message received, continue
              @is_running = false
            end
          end.join
          handle(msg) if msg.present?
        rescue StandardError => ex
          PulsarJob.logger.error "Error while receiving message: #{ex.message}"
        ensure
          @is_running = false
        end
      end
    end

    def handle(msg)
      # Reset the job instance
      payload = process_payload(msg)
      job.run_callbacks(:perform) do
        begin
          puts "===== debug job #{job.inspect} | #{msg.inspect}"
          puts "===== payload #{payload.inspect}"
          if job.payload_as_args?
            # Enqueuing jobs with method arguments, hash keys are ignored
            args = payload.try(:[], 'args')
            args = args.values if args.is_a?(Hash)
            job.perform(*args)
          else
            job.perform({
              payload: payload,
              message_id: msg.message_id,
              raw: msg,
            })
          end
          PulsarJob.logger.debug "Message handled successfully"
          consumer.acknowledge(msg)
        rescue ArgumentError => ex
          PulsarJob.logger.error "Error while handling message: #{ex.message}. Message: #{ex.message}"
          # Interface mismatch, move to DLQ
          # TODO: Move to DLQ right away
          consumer.acknowledge(msg)
        rescue StandardError => ex
          PulsarJob.logger.error "Error while handling message: #{ex.inspect}. Message: #{ex.message}"
          # Automatically nack messages that fail
          consumer.negative_acknowledge(msg)
        end
      end
    rescue StandardError => ex
      PulsarJob.logger.error "Error while handling message: #{ex.message}. Message: #{ex.message}"
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
