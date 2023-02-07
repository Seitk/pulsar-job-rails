# frozen_string_literal: true

module PulsarJob
  class AsyncWrapper < Base
    include Context

    attr_accessor :klass
    attr_accessor :instance_id
    attr_accessor :method
    attr_accessor :context
    attr_reader :job

    def initialize(klass)
      @klass = klass
      @instance_id = nil
      @method = nil
      @context = nil
      @job = nil
    end

    def method_missing(method, *args)
      @method = method
      @context = args
      @job
    end
  end
end
