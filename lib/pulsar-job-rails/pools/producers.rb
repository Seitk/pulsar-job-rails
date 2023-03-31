# frozen_string_literal: true

module PulsarJob
  module Pools
    module Producers
      class << self
        @@pulsar_job_pool_producers_lock = Mutex.new

        # For the same topic, there would be only one producer allowed
        # So this pool is used to store the producer used previously
        def get(topic, &block)
          @@pulsar_job_pool_producers_lock.synchronize {
            $pulsar_job_pool_producers ||= {}
            raw_producer = $pulsar_job_pool_producers[topic].try(:producer)
            if raw_producer.nil?
              raw_producer = create(topic)
              $pulsar_job_pool_producers[topic] = yield raw_producer
            end
            raw_producer
          }
        end

        def create(topic)
          Client.instance_exec do |instance|
            instance.create_producer(topic, producer_options)
          end
        end

        def shutdown
          return if $pulsar_job_pool_producers.blank?

          $pulsar_job_pool_producers.each do |topic, producer|
            producer.shutdown
          end
          PulsarJob.logger.debug "Pulsar producers closed"
        end

        def producer_options
          options = Pulsar::ProducerConfiguration.new
          options.send_timeout_millis = PulsarJob.configuration.producer_send_timeout_millis
          options.producer_name = producer_name
          options
        end

        def producer_name
          host_id = if defined?(Socket)
              Socket.gethostname
            else
              SecureRandom.hex(8)
            end
          "pulsar-job-producer-#{host_id}"
        end
      end
    end
  end
end
