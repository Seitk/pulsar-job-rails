# frozen_string_literal: true

module PulsarJob
  module Async
    class Wrapper < Base
      attr_accessor :klass, :instance

      class AsyncMethodMissingError < StandardError; end
      class AsyncInvalidContextError < StandardError; end

      def initialize(klass)
        @klass = klass
        @instance = nil
      end

      def set(options)
        return self unless options.is_a?(Hash)
        options.each do |key, value|
          send("#{key}=", value) if defined?("key=")
        end
        self
      end

      def payload_as_args?
        false
      end

      def perform(payload:, message_id:, raw:)
        klass = payload["klass"].constantize
        @instance = nil
        if payload["id"].present?
          @instance = klass.find(payload["id"])
        end
        if @instance.present?
          @instance.send(payload["method"].to_sym, *(payload["args"] || []))
        else
          klass.send(payload["method"].to_sym, *(payload["args"] || []))
        end
      rescue NameError => ex
        raise AsyncInvalidContextError.new("Async execution failed, class #{payload["klass"]} is invalid. #{ex.message}}")
      end

      def method_missing(method_name, *args)
        enqueue(method_name, args)
        self
      end

      def enqueue(method_name, args)
        @method = method_name
        @args = args

        validate_caller!
        validate_context!

        payloads ||= {
          klass: @klass.name,
          method: @method,
          args: args,
        }
        if @instance.present? && @instance.respond_to?(:id)
          payloads[:id] = instance.id
        end

        # Enqueue
        PulsarJob.logger.debug "Enqueueing async job for #{klass.name}.#{method_name} with #{payloads.inspect}"
        producer = PulsarJob::Produce.new(job: self)
        producer.publish!(payloads)
      end

      private

      def validate_caller!
        if (@instance.present? && !@instance.respond_to?(@method)) ||
           (@instance.nil? && !@klass.respond_to?(@method))
          raise AsyncMethodMissingError.new("Async execution failed, method #{@method} not found")
        end
      end

      def validate_context!
        raise AsyncInvalidContextError.new("Async execution failed, context is not valid") unless context_valid?
      end
    end
  end
end
