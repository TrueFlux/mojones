# Changelog

## 0.2.0 (unreleased)

### Breaking

- **The first matching handler now wins, and later handlers don't run.**
  Before, every matching handler ran and the last one's result was
  returned. If you put a catch-all before a more specific handler, swap
  them so the specific one comes first:

  ```ruby
  # 0.1.0
  m.failure { |_| "Something went wrong" }
  m.failure(:card_declined) { |_| "Your card was declined" }

  # 0.2.0
  m.failure(:card_declined) { |_| "Your card was declined" }
  m.failure { |_| "Something went wrong" }
  ```

- **Failure values other than Symbols and exceptions reach the handler
  unchanged.** For example, `Failure(user.errors)` now yields the errors
  object. Before, it became a string: `to_s`, or a "translation missing"
  message when I18n was loaded.
- **Ruby 3.3 or later is required.** Ruby 3.2 reached end of life in March 2026.

### Fixed

- `rails generate mojones:service` works when the gem is installed from
  RubyGems. The template was missing from the packaged gem.
- Failures from anonymous service or exception classes no longer raise
  `NoMethodError` when I18n is loaded.
- Apps that load I18n without ActiveSupport no longer raise
  `NoMethodError` from failure handlers. Translation is skipped instead.
- The matcher no longer writes debug output to stdout outside Rails.

## 0.1.0 (2026-03-21)

- Initial release.
