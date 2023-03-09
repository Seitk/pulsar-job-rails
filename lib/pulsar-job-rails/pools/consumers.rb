# frozen_string_literal: true

module PulsarJob
  module Pools
    module Consumers
      class << self
        @@pulsar_job_pool_consumers_lock = Mutex.new

        def get(topic)
          @@pulsar_job_pool_consumers_lock.synchronize {
            $pulsar_job_pool_consumers ||= {}
            $pulsar_job_pool_consumers[topic]
          }
        end

        def subscribe(topic, subscription, options = {})
          @@pulsar_job_pool_consumers_lock.synchronize do
            key = "#{topic}-#{subscription}"

            $pulsar_job_pool_consumers ||= {}
            return $pulsar_job_pool_consumers[key] if $pulsar_job_pool_consumers[key]

            consumer = Client.instance_exec do |instance|
              instance.subscribe(topic, subscription, options)
            end
            $pulsar_job_pool_consumers ||= {}
            $pulsar_job_pool_consumers[key] ||= consumer
            consumer
          end
        end

        def shutdown
          return if $pulsar_job_pool_consumers.blank?

          $pulsar_job_pool_consumers.each do |_, consumer|
            consumer.close
          end
          PulsarJob.logger.debug "Pulsar consumers closed"
        end
      end
    end
  end
end
