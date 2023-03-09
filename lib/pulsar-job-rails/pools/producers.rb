# frozen_string_literal: true

module PulsarJob
  module Pools
    module Producers
      class << self
        @@pulsar_job_pool_producers_lock = Mutex.new

        def get(topic)
          @@pulsar_job_pool_producers_lock.synchronize {
            $pulsar_job_pool_producers ||= {}
            producer = $pulsar_job_pool_producers[topic]
            if producer.nil?
              $pulsar_job_pool_producers[topic] = create(topic)
              producer = $pulsar_job_pool_producers[topic]
            end
            producer
          }
        end

        def set(topic, producer)
          @@pulsar_job_pool_producers_lock.synchronize {
            $pulsar_job_pool_producers ||= {}
            $pulsar_job_pool_producers[topic] ||= producer
            producer
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
            producer.close
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
          host_id =
            if defined?(Socket)
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
