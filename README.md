# Mojones

Service objects with monadic result handling. A lightweight framework
around [dry-monads](https://dry-rb.org/gems/dry-monads/) that gives every
service object one enforced shape — `.call` always returns a `Success`/
`Failure` result (or raises), and a small block-based matcher lets callers
branch on the outcome without a pile of `if result.success?` checks.

## Installation

```
bundle add mojones
```

Or add it to your Gemfile directly:

```ruby
gem "mojones"
```

## Usage

Inherit from `Mojones::Base` and return a `Dry::Monads::Result` from
`#call`:

```ruby
class CreateUser < Mojones::Base
  include Dry::Monads[:result]

  def initialize(params)
    @params = params
  end

  def call
    user = User.new(@params)
    return Failure(user.errors) unless user.save

    Success(user)
  end
end
```

Calling `.call` without a block just gives you the raw value — a `User` on
success, or whatever you passed to `Failure(...)` if it failed:

```ruby
CreateUser.call(params) # => #<User ...> or the failure value
```

Pass a block to match on the outcome instead:

```ruby
CreateUser.call(params) do |m|
  m.success { |user| redirect_to user }
  m.failure { |errors| render :new, status: :unprocessable_entity }
end
```

`success`/`failure` can also filter on the matched value/error, letting you
handle specific cases before falling through to a catch-all:

```ruby
ChargeCard.call(order) do |m|
  m.failure(CardDeclined) { |_| redirect_to retry_payment_path }
  m.failure { |error| raise error }
  m.success { |charge| redirect_to receipt_path(charge) }
end
```

If more than one handler matches, the **last** match wins (and a warning
is logged) — this mirrors `case`/`when` fallthrough rather than raising,
so ordering handlers from more to less specific is up to you.

If a service's `#call` raises instead of returning a `Result`, or returns
something that isn't a `Dry::Monads::Result` at all, `Mojones::Base` turns
that into a matchable failure too (or re-raises, if nothing calls `.value!`
on it) rather than letting it escape silently as a bare exception or a
malformed result.

### Rails generator

```
bin/rails generate mojones:service CreateUser
```

Scaffolds `app/services/create_user.rb` with the `Mojones::Base` skeleton
above.

## Development

```
bundle install
bundle exec rspec    # tests
bundle exec rubocop  # lint
```

CI (`.github/workflows/`) runs both on every push and pull request.

## License

MIT.

---

Built by [TrueFlux](https://trueflux.agency).
