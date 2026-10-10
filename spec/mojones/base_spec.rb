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

    it "re-raises when called without a block" do
      expect { ErrorService.call }.to raise_error(RuntimeError, "boom")
    end

    it "is matchable as a failure" do
      value = ErrorService.call do |m|
        m.failure(RuntimeError) { |error, _message| error }
      end

      expect(value).to be_a(RuntimeError).and have_attributes(message: "boom")
    end

    it "re-raises when no handler matches" do
      expect do
        ErrorService.call { |m| m.failure(ArgumentError) { |_| "won't run" } }
      end.to raise_error(RuntimeError, "boom")
    end
  end

  context "when the initializer raises" do
    before do
      stub_const("InitErrorService", Class.new(Mojones::Base) do
        def initialize(_arg)
          super()
          raise ArgumentError, "bad arg"
        end

        def call = Success(:ok)
      end)
    end

    it "is matchable as a failure" do
      value = InitErrorService.call(1) do |m|
        m.failure(ArgumentError) { |error, _message| error.message }
      end

      expect(value).to eq("bad arg")
    end
  end

  context "when the service takes arguments" do
    before do
      stub_const("ArgsService", Class.new(Mojones::Base) do
        def initialize(first, second:)
          super()
          @first = first
          @second = second
        end

        def call = Success([@first, @second])
      end)
    end

    it "passes positional and keyword arguments to the initializer" do
      expect(ArgsService.call(1, second: 2).value!).to eq([1, 2])
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
        Mojones::Base::Errors::ServiceReturnedNonResult,
        "Service BadService returned non-Result value (:not_a_monad : Symbol)"
      )
    end

    it "raises even when a failure handler would match" do
      expect do
        BadService.call { |m| m.failure { |_| "won't run" } }
      end.to raise_error(Mojones::Base::Errors::ServiceReturnedNonResult)
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
      hide_const("I18n")
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
      end.to raise_error(Mojones::Base::Errors::NoHandlerMatched, "No handler matched for Success(:ok)")
    end
  end

  context "when handlers filter on the value" do
    before do
      stub_const("FilterService", Class.new(Mojones::Base) do
        def call = Failure(:declined)
      end)
    end

    it "only runs handlers whose patterns match with ===" do
      value = FilterService.call do |m|
        m.failure(:other) { |_| "other" }
        m.failure(:expired, :declined) { |_| "declined" }
        m.failure { |_| "catch-all" }
      end

      expect(value).to eq("declined")
    end

    it "gives two-argument failure blocks the raw error and the message" do
      hide_const("I18n")

      value = FilterService.call do |m|
        m.failure { |error, message| [error, message] }
      end

      expect(value).to eq([:declined, "declined"])
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

    it "returns the first match" do
      value = MultiMatchService.call do |m|
        m.success { |_| "first" }
        m.success { |_| "second" }
      end

      expect(value).to eq("first")
    end

    it "does not run later matching handlers" do
      ran = []

      MultiMatchService.call do |m|
        m.success { |_| ran << :first }
        m.success { |_| ran << :second }
      end

      expect(ran).to eq([:first])
    end

    it "returns a falsy first match rather than raising NoHandlerMatched" do
      value = MultiMatchService.call do |m|
        m.success { |_| nil }
        m.success { |_| "second" }
      end

      expect(value).to be_nil
    end
  end
end
