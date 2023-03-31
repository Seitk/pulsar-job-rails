# frozen_string_literal: true

require "pulsar/consumer"
require "pulsar-job-rails/consumes/base"
require "pulsar-job-rails/consumes/batched"
require "pulsar-job-rails/consumes/one"

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
        @consumer = PulsarJob::Pools::Consumers.subscribe([job.topic], job.subscription, job.consumer_options) do |raw_consumer|
          self
        end
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
        PulsarJob.logger.debug "Waiting for #{job.batched_consume? ? "batched " : ""}message..."
        begin
          msg = nil
          consume = consumer_by_job(job)

          # Consumer receive will lock up the main thread, run in a new thread to handle gracefully shutdown
          Thread.new do
            begin
              msg = consume.receive
            rescue Pulsar::Error::AlreadyClosed, SystemExit
              @is_running = false
            rescue Pulsar::Error::Timeout
              # No message received, continue
            rescue StandardError => ex
              PulsarJob.logger.error "Error on polling consumer: #{ex.message}"
            end
          end.join

          consume.handle if msg.present?

          if PulsarJob.configuration.consumer_receive_internal_millis > 0
            sleep(PulsarJob.configuration.consumer_receive_internal_millis / 1000.0)
          end
        rescue StandardError => ex
          PulsarJob.logger.error "Error on listening message: #{ex.message}"
          PulsarJob.logger.error ex.backtrace.join("\n")
        rescue Pulsar::Error::AlreadyClosed, SystemExit
          @is_running = false
        ensure
          @is_running = false
        end
      end
      @is_running = false
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

    def consumer_by_job(job)
      adapter = begin
          if job.batched_consume?
            PulsarJob::Consumes::Batched.new(job)
          else
            PulsarJob::Consumes::One.new(job)
          end
        end

      adapter.consumer = consumer

      adapter
    end
  end
end
