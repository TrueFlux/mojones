# frozen_string_literal: true

require "logger"

module Mojones
  class Matcher
    class Match
      attr_reader :matched, :result

      def initialize(matched:, result:)
        @matched = matched
        @result = result
      end

      class Success < self; end
      class Failure < self; end
    end

    def initialize(service_result, service)
      @service = service
      @service_result = service_result
      @matches = []
      yield(self) if block_given?
    end

    def result
      return @service_result.no_matches! if @matches.empty?

      @matches.last.result.tap do |chosen|
        if @matches.size > 1
          logger.debug <<~WARNING
            #{service.name} matched multiple handlers; returning last result (#{chosen})
          WARNING
        end
      end
    end

    def success(*match_values, &block)
      return unless @service_result.success?

      value = @service_result.original

      return unless match_values.empty? || match_values.any? { _1 === value } # rubocop:disable Style/CaseEquality

      @matches << Match::Success.new(
        matched: value,
        result: block.call(value)
      )
    end

    def failure(*match_errors, &block)
      return unless @service_result.failure?

      error = @service_result.original

      return unless match_errors.empty? || match_errors.any? { _1 === error } # rubocop:disable Style/CaseEquality

      translated = translate_error(error)

      @matches << Match::Failure.new(
        matched: error,
        result: block.arity == 2 ? block.call(error, translated) : block.call(translated)
      )
    end

    private

    attr_reader :service

    def logger
      @logger ||= defined?(Rails) ? Rails.logger : Logger.new($stdout)
    end

    def translate_error(error)
      return error unless error.is_a?(Symbol) || error.is_a?(StandardError)
      return error.to_s unless translatable?(error)

      I18n.t(error_key(error), default: error_default(error))
    end

    # Keys are built from class names, so anonymous classes can't be translated.
    def translatable?(error)
      i18n_available? && service.name && (error.is_a?(Symbol) || error.class.name)
    end

    # Key building and defaults use ActiveSupport's inflector.
    def i18n_available?
      defined?(I18n) && defined?(ActiveSupport::Inflector)
    end

    def error_key(error)
      key = error.is_a?(Symbol) ? error : i18n_path(error.class.name)
      "#{i18n_path(service.name)}.#{key}"
    end

    def error_default(error)
      error.is_a?(Symbol) ? ActiveSupport::Inflector.humanize(error) : error.message
    end

    def i18n_path(name)
      ActiveSupport::Inflector.underscore(name.gsub("::", "."))
    end
  end
end
