# frozen_string_literal: true

require "mojones"
require "i18n"
require "active_support/inflector"

describe Mojones::Matcher do
  def failure_service(error)
    Class.new(Mojones::Base) do
      define_method(:call) { Failure(error) }
    end
  end

  def handle_failure(service)
    service.call do |m|
      m.failure { |translated| translated }
    end
  end

  before do
    I18n.backend = I18n::Backend::Simple.new
    I18n.backend.store_translations(:en, translated_service: { bad: "Translated bad" })
  end

  context "when I18n is loaded" do
    it "translates Symbol failures under the service's key" do
      stub_const("TranslatedService", failure_service(:bad))

      expect(handle_failure(TranslatedService)).to eq("Translated bad")
    end

    it "falls back to a humanized Symbol" do
      stub_const("TranslatedService", failure_service(:no_translation))

      expect(handle_failure(TranslatedService)).to eq("No translation")
    end

    it "falls back to the exception message" do
      stub_const("TranslatedService", failure_service(ArgumentError.new("nope")))

      expect(handle_failure(TranslatedService)).to eq("nope")
    end

    it "passes other failure values through untouched" do
      errors = { name: ["can't be blank"] }
      stub_const("TranslatedService", failure_service(errors))

      expect(handle_failure(TranslatedService)).to be(errors)
    end
  end

  context "when I18n is not loaded" do
    before { hide_const("I18n") }

    it "passes Symbol failures as strings" do
      stub_const("TranslatedService", failure_service(:bad))

      expect(handle_failure(TranslatedService)).to eq("bad")
    end

    it "passes other failure values through untouched" do
      errors = { name: ["can't be blank"] }
      stub_const("TranslatedService", failure_service(errors))

      expect(handle_failure(TranslatedService)).to be(errors)
    end
  end
end
