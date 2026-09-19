# yamshik-cdek

[Yamshik](https://github.com/Kroch4ka/yamshik) plugin for CDEK (СДЭК) — parcel creation and registration status refresh via CDEK API v2.

> Status: early development, the adapter is being implemented.

## Installation

```bash
bundle add yamshik-cdek
```

## Usage

```ruby
require "yamshik/cdek"

Yamshik.configure do |config|
  config.register :cdek, client_id: ENV["CDEK_CLIENT_ID"],
                         client_secret: ENV["CDEK_CLIENT_SECRET"],
                         sandbox: true
end

cdek = Yamshik.carrier(:cdek)
```

## carrier_options

CDEK-specific options accepted in calls (validated by the adapter, unknown
keys are rejected with `:validation_failed`):

_None yet — will be documented with the adapter implementation._

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Kroch4ka/yamshik-cdek. The process matches the core repo: see [CONTRIBUTING.md](https://github.com/Kroch4ka/yamshik/blob/main/CONTRIBUTING.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
