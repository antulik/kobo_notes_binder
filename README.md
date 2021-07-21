# KoboNotesBinder

KoboNotesBinder exports your Kobo book highlights bound inside the book.
In other words, you get a copy of the book with your markings in it.

This is an early version and most likely there cases that it doesn't support. If you found issues or have ideas please raise them here. 

The tool never changes files on the device, so it is safe to use it.

## Installation

    $ gem install kobo_notes_binder

## Usage

1. Plug-in Kobo device 
2. Run command `kobo_notes_binder` in terminal and follow instructions
3. Find book on your Desktop

## Advance Usage

`kobo_notes_binder -h`

## Features

- Export embedded book highlights

Not tested
- Ruby version less than 3.0
- Non-DRM books purchased in Kobo store

Not supported
- Export of written annotations
- Export of page bookmarks
- Color customisation
- DRM books


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/antulik/kobo_notes_binder. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/antulik/kobo_notes_binder/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the KoboNotesBinder project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/antulik/kobo_notes_binder/blob/master/CODE_OF_CONDUCT.md).
