# frozen_string_literal: true

require_relative "lib/mojones/version"

Gem::Specification.new do |s|
  s.name        = "mojones"
  s.version     = Mojones::VERSION
  s.summary     = "Service objects with monadic result handling"
  s.description = "A lightweight framework for Ruby service objects using Dry::Monads with enforced result types and matching."
  s.authors     = ["Phil Brockwell", "Habib Alamin"]
  s.email       = ["phil@trueflux.agency", "habib@trueflux.agency"]
  s.files       = Dir["lib/**/*", "README.md", "CHANGELOG.md", "LICENSE.txt"]
  s.homepage    = "https://github.com/TrueFlux/mojones"
  s.license     = "MIT"
  s.required_ruby_version = ">= 3.3"

  s.add_dependency "dry-monads", "~> 1.3"
  s.metadata["changelog_uri"] = "https://github.com/TrueFlux/mojones/blob/main/CHANGELOG.md"
  s.metadata["rubygems_mfa_required"] = "true"
end
