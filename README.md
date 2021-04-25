# Blink-TM
Blink task manager allows you to monitor your system resources using Arduino connected to 128x64 OLED display.

![Preview](https://github.com/Souravgoswami/blink-tm/blob/master/previews/preview.gif)

## Installation
Blink-taskmanager should be installed on your Arduino.
Your arduino has to be attached with a rit-253 or similar 128x64 OLED display that can utilize the graphics library from Adafruit.

1. Install the [blink-taskmanager](https://github.com/Souravgoswami/blink-taskmanager) on your arduino.
2.  Install this gem on your computer, laptop, raspberry pi, etc. as:

```
$ gem install blink-tm
```

## Usage
Make sure your arduino is connected to your computer.
Although blink-taskmanager is hot pluggable, and blink-tm works fine with that.

Launch blink-taskmanager with `blink-tm` command on your PC.

## Development
After checking out the repo, run `bin/setup` to install dependencies.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing
Bug reports and pull requests are welcome on GitHub at https://github.com/Souravgoswami/ice-tm.

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
