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

      def fmap
        yield @value
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

    class InitializerReturnedValue < ReturnedValue
      def success? = true
      def failure? = true
      def original = @value

      def assert_call_returned_result_monad_or_raised!
        self
      end
    end

    class CallReturnedValue < ReturnedValue
      def initialize(service, value)
        super(value)
        @service = service
        @value = value
      end

      def assert_call_returned_result_monad_or_raised!
        return self if @value.is_a?(Dry::Monads::Result)

        raise Errors::ServiceReturnedNonResult.new(@service, @value)
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

      def fmap
        self
      end

      def no_matches!
        raise @error
      end

      def assert_call_returned_result_monad_or_raised!
        self
      end
    end

    def self.call(*args, **kwargs, &)
      result = (
        begin
          InitializerReturnedValue.new(new(*args, **kwargs))
        rescue StandardError => e
          RaisedError.new(e)
        end
      ).fmap do |service_object|
        CallReturnedValue.new(service_object, service_object.call)
      rescue StandardError => e
        RaisedError.new(e)
      end.assert_call_returned_result_monad_or_raised!

      return result.value! unless block_given?

      Matcher.new(result, self, &).result
    end
  end
end
