# frozen_string_literal: true

module Mojones
  class Base
    include Dry::Monads[:result, :do]

    module Errors
      class NoHandlerMatched < StandardError
        def initialize(value)
          super
          @value = value
        end

        def message = "No handler matched for #{@value.inspect}"
      end

      class ServiceReturnedNonResult < StandardError
        def initialize(service, value)
          super(value)
          @service_name = service.class.inspect.sub(/^Mojones::/, "")
          @value = value
        end

        def message
          "Service #{@service_name} returned non-Result value (#{@value.inspect} : #{@value.class})"
        end
      end
    end

    class ReturnedValue
      def initialize(value)
        @value = value
      end

      def value!
        @value
      end

      def success?
        @value.success?
      end

      def failure?
        @value.failure?
      end

      def original
        @value.either(:itself.to_proc, :itself.to_proc)
      end

      def no_matches!
        raise Errors::NoHandlerMatched, @value
      end
    end

    class RaisedError
      def initialize(error)
        @error = error
      end

      def success? = false
      def failure? = true

      def value!
        raise @error
      end

      def original
        @error
      end

      def no_matches!
        raise @error
      end
    end

    def self.call(*, **, &)
      result = execute(*, **)
      return result.value! unless block_given?

      Matcher.new(result, self, &).result
    end

    # Errors raised by the service become a matchable RaisedError. Returning a
    # non-Result is a bug in the service, so it raises instead (an exception
    # raised in `else` isn't caught by the method's `rescue`).
    def self.execute(*, **)
      service = new(*, **)
      value = service.call
    rescue StandardError => e
      RaisedError.new(e)
    else
      raise Errors::ServiceReturnedNonResult.new(service, value) unless value.is_a?(Dry::Monads::Result)

      ReturnedValue.new(value)
    end
    private_class_method :execute
  end
end
