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

Calling `.call` without a block gives you the `Result` itself:

```ruby
result = CreateUser.call(params) # => Success(#<User ...>) or Failure(#<ActiveModel::Errors ...>)
result.value!                    # => #<User ...>, or raises on failure
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

If the service raises, the exception is matchable as a failure, so
`m.failure(ActiveRecord::RecordNotFound) { ... }` works. Without a block,
or when no handler matches, the exception is re-raised.

If `#call` returns something that isn't a `Dry::Monads::Result`, `.call`
raises `Mojones::Base::Errors::ServiceReturnedNonResult`. That's a bug in
the service, so it can't be matched.

### Failure values and I18n

A one-argument `failure` block gets the failure value translated:

- A Symbol is looked up under the service's I18n scope, so
  `Failure(:card_declined)` in `Billing::ChargeCard` is looked up as
  `billing.charge_card.card_declined`. If there's no translation, it falls
  back to `"Card declined"`.
- An exception is looked up by its class name, falling back to its message.
- Any other value (for example `user.errors`) is passed through unchanged.

Translation needs I18n and ActiveSupport, so in practice it means Rails.
Without them, Symbols and exceptions arrive as `to_s` strings. Anonymous
classes are never translated.

To get the untranslated value as well, take two arguments:

```ruby
m.failure { |error, message| flash[:alert] = message }
```

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

MIT — see `LICENSE.txt`.

---

Built by [TrueFlux](https://trueflux.agency).
