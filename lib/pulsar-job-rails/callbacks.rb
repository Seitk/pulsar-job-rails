# frozen_string_literal: true

require 'active_support/concern'
require "active_support/callbacks"

module PulsarJob
  module Callbacks
    extend ActiveSupport::Concern

    class << self
      include ActiveSupport::Callbacks
      define_callbacks :execute
    end
    
    included do
      include ActiveSupport::Callbacks
      define_callbacks :perform
      define_callbacks :enqueue
    end

    module ClassMethods
      def before_perform(*filters, &block)
        set_callback(:perform, :before, *filters, &block)
      end

      def after_perform(*filters, &block)
        set_callback(:perform, :after, *filters, &block)
      end

      def before_enqueue(*filters, &block)
        set_callback(:enqueue, :before, *filters, &block)
      end

      def after_enqueue(*filters, &block)
        set_callback(:enqueue, :after, *filters, &block)
      end
    end
  end
end
