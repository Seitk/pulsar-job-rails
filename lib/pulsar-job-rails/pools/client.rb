# frozen_string_literal: true

module PulsarJob
  module Pools
    module Client
      class << self
        class InvalidClientConfigirationError < StandardError; end

        @@pulsar_job_pool_client_lock = Mutex.new

        def instance
          $pulsar_job_pool_client
        end

        def connect(host)
          config = Pulsar::ClientConfiguration.new
          config.operation_timeout_seconds = PulsarJob.configuration.pulsar_broker_operation_timeout_seconds
          config.connection_timeout_ms = PulsarJob.configuration.pulsar_broker_connection_timeout_ms
          ::Pulsar::Client.new("pulsar://#{host}", config)
        end

        # Get a pulsar client instance with ability to try with broker hosts
        # in case of connection failure or single broker is down
        def instance_exec(&block)
          max_retries = PulsarJob.configuration.pulsar_broker_max_retries
          brokers = broker_hosts
          instance = nil
          host = nil
          result = nil
          begin
            raise InvalidClientConfigirationError.new("No connectable broker available") if brokers.length == 0

            @@pulsar_job_pool_client_lock.synchronize {
              host = brokers[0]
              instance = connect(host)
              result = yield instance
              $pulsar_job_pool_client = instance
            }
          rescue Pulsar::Error::ConnectError => e
            # Retry with another endpoint
            PulsarJob.logger.error "Failed to connect to broker #{host}: #{e.message}"

            max_retries -= 1
            if max_retries <= 0
              raise InvalidClientConfigirationError.new("Unable to connect to any broker after #{PulsarJob.configuration.pulsar_broker_max_retries} retries")
            end

            # Continue on another broker
            brokers.shift()
            if brokers.length == 0
              brokers = broker_hosts
            end

            sleep(PulsarJob.configuration.pulsar_broker_retry_interval_seconds)

            retry # ⤴
          rescue => e
            raise e
          end

          result
        end

        def shutdown
          $pulsar_job_pool_client.try(:close)
          PulsarJob.logger.debug "Pulsar client closed"
        end

        private

        def broker_hosts
          @broker_hosts ||= begin
              matches = PulsarJob.configuration.pulsar_broker_url.match(/pulsar:\/\/(.+)/)
              raise InvalidClientConfigirationError.new("Invalid client configuration") if matches.length < 2
              matches[1].split(",")
            end
          @broker_hosts.dup.shuffle
        end
      end
    end
  end
end
