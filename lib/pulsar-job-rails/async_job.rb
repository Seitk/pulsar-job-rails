# frozen_string_literal: true

module PulsarJob
  class AsyncJob < Base
    attr_accessor :klass
    attr_accessor :instance
    attr_accessor :method
    attr_accessor :context
    attr_accessor :options

    class AsyncMethodMissingError < StandardError; end
    class AsyncInvalidContextError < StandardError; end

    def initialize(klass)
      @klass = klass
      @instance = nil
      @flatten_payloads = true
    end

    def method_missing(method, *args)
      @method = method
      @args = args
      
      validate_caller!
      validate_context!

      payloads = []
      if instance.present? && instance.respond_to?(:id)
        payloads << instance.id
      end

      payloads.concat(args)

      # Enqueue

      self
    end

    private

    def validate_caller!
      if (instance.present? && !@instance.respond_to?(method)) || 
        (instance.nil? && !@klass.respond_to?(method))
        raise AsyncMethodMissingError.new("Async execution failed, method #{method} not found")
      end
    end

    def validate_context!
      raise AsyncInvalidContextError.new("Async execution failed, context is not valid") unless context_valid?
    end
  end
end
