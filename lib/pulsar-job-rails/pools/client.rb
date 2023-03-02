# frozen_string_literal: true

module PulsarJob
  module Pools
    module Client
      class << self
        class InvalidClientConfigirationError < StandardError; end

        @@pulsar_job_pool_client_lock = Mutex.new

        def instance
          @@pulsar_job_pool_client_lock.synchronize {
            $pulsar_job_pool_client ||= connect_brokers
          }
        end

        def shutdown
          $pulsar_job_pool_client.close
          PulsarJob.logger.debug "Pulsar client closed"
        end

        private

        def connect_brokers
          matches = PulsarJob.configuration.pulsar_broker_url.match(/pulsar:\/\/(.+)/)
          raise InvalidClientConfigirationError.new("Invalid client configuration") if matches.length < 2
          brokers = matches[1].split(",")

          healthy_brokers = []
          brokers.each do |broker|
            begin
              healthy_brokers << broker if attempt_connection(broker)
            rescue => e
              PulsarJob.logger.error "Failed to connect to broker #{broker}: #{e.message}"
            end
          end

          if healthy_brokers.empty?
            raise InvalidClientConfigirationError.new("No healthy brokers found")
          end
          
          puts "====== wtf??, #{healthy_brokers.inspect}"
          ::Pulsar::Client.new("pulsar://#{healthy_brokers.join(",")}", Pulsar::ClientConfiguration.new)
        end

        def attempt_connection(broker)
          attempts ||= 1
          ::Pulsar::Client.new("pulsar://#{broker}", Pulsar::ClientConfiguration.new)
          broker
        rescue => error
          PulsarJob.logger.error "Failed to connect to broker #{broker}: #{error.message}. Attempt #{attempts} of 5"
          if (attempts += 1) < 5 # go back to begin block if condition ok
            PulsarJob.logger.error "<retrying..>"
            sleep 1
            retry # ⤴
          end
          puts "Exceeded attempts on broker #{broker}, giving up"
          false
        end
      end
    end
  end
end
