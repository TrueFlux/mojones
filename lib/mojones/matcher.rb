# frozen_string_literal: true

require "logger"

module Mojones
  class Matcher
    def initialize(service_result, service)
      @service = service
      @service_result = service_result
      @results = []
      yield(self) if block_given?
    end

    def result
      return @service_result.no_matches! if @results.empty?

      @results.last.tap do |chosen|
        if @results.size > 1
          logger.debug <<~WARNING
            #{service.name} matched multiple handlers; returning last result (#{chosen})
          WARNING
        end
      end
    end

    def success(*patterns)
      return unless @service_result.success?

      value = @service_result.original
      return unless matches?(patterns, value)

      @results << yield(value)
    end

    def failure(*patterns, &block)
      return unless @service_result.failure?

      error = @service_result.original
      return unless matches?(patterns, error)

      translated = translate_error(error)
      @results << (block.arity == 2 ? yield(error, translated) : yield(translated))
    end

    private

    attr_reader :service

    # Matches like case/when, so classes, ranges, regexps and plain values all work.
    def matches?(patterns, value)
      return true if patterns.empty?

      case value
      when *patterns then true
      else false
      end
    end

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
