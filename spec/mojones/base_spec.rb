# frozen_string_literal: true

require "mojones"

describe Mojones::Base do
  context "when the service is a success" do
    before do
      stub_const("SuccessService", Class.new(Mojones::Base) do
        def call
          Success(:ok)
        end
      end)
    end

    let(:result) { SuccessService.call }

    it "returns a success value" do
      expect(result).to be_success
      expect(result.value!).to eq(:ok)
    end
  end

  context "when the service is a failure" do
    before do
      stub_const("FailureService", Class.new(Mojones::Base) do
        def call
          Failure(:bad)
        end
      end)
    end

    let(:result) { FailureService.call }

    it "returns a failure value" do
      expect(result).to be_failure
      expect(result.failure).to eq(:bad)
    end
  end

  context "when the service raises an error" do
    before do
      stub_const("ErrorService", Class.new(Mojones::Base) do
        def call
          raise "boom"
        end
      end)
    end

    let(:result) { ErrorService.call }

    it "wraps the error as a failure-like result" do
      expect { result.value! }.to raise_error(RuntimeError, "boom")
    end
  end

  context "when the service returns a non-monad value" do
    before do
      stub_const("BadService", Class.new(Mojones::Base) do
        def call
          :not_a_monad
        end
      end)
    end

    it "raises an error" do
      expect { BadService.call }.to raise_error(
        Mojones::Base::Errors::ServiceReturnedNonResult
      )
    end
  end

  context "when using matcher with success" do
    before do
      stub_const("MatchSuccessService", Class.new(Mojones::Base) do
        def call
          Success(:ok)
        end
      end)
    end

    it "yields to the success block" do
      value = MatchSuccessService.call do |m|
        m.success do |v|
          "handled #{v}"
        end
      end

      expect(value).to eq("handled ok")
    end
  end

  context "when using matcher with failure" do
    before do
      stub_const("MatchFailureService", Class.new(Mojones::Base) do
        def call
          Failure(:bad)
        end
      end)
    end

    it "yields to the failure block" do
      value = MatchFailureService.call do |m|
        m.failure do |err|
          "handled #{err}"
        end
      end

      expect(value).to eq("handled bad")
    end
  end

  context "when no matcher handles the result" do
    before do
      stub_const("NoMatchService", Class.new(Mojones::Base) do
        def call
          Success(:ok)
        end
      end)
    end

    it "raises NoHandlerMatched" do
      expect do
        NoMatchService.call do |m|
          m.failure { |_| "won't run" }
        end
      end.to raise_error(Mojones::Base::Errors::NoHandlerMatched)
    end
  end

  context "when multiple matchers match" do
    before do
      stub_const("MultiMatchService", Class.new(Mojones::Base) do
        def call
          Success(:ok)
        end
      end)
    end

    it "returns the last match" do
      value = MultiMatchService.call do |m|
        m.success { |_| "first" }
        m.success { |_| "second" }
      end

      expect(value).to eq("second")
    end
  end
end
