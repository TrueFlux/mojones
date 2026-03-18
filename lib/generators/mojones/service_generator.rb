# frozen_string_literal: true

require "rails/generators"

module Mojones
  module Generators
    class ServiceGenerator < Rails::Generators::NamedBase
      source_root File.expand_path("templates", __dir__)

      def create_service_file
        template "service.rb.tt", File.join("app/services", class_path, "#{file_name}.rb")
      end
    end
  end
end
