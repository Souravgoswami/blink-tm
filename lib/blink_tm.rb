# Frozen_String_Literal: true
require 'blink_tm/baudrate'

module BlinkTM
	# Important Constants
	BAUDRATE = BlinkTM::B57600
	SCANID = 'BTM'

	# POLLING time, how often should CPU, Net, IO usages should be updated.
	# Should always be a float.
	POLLING = 0.375

	# Refresh time, how often the main loop should run
	REFRESH = 0.5

	# Errors
	NoDeviceError = Class.new(StandardError)
	DeviceNotReady = Class.new(StandardError)

	# Units
	TB = 10 ** 12
	GB = 10 ** 9
	MB = 10 ** 6
	KB = 10 ** 3

	# ANSI Sequences
	RED = "\e[38;2;225;79;67m"
	BLUE = "\e[38;2;45;125;255m"
	GREEN = "\e[38;2;40;175;95m"
	ORANGE = "\e[38;2;245;155;20m"
	BOLD = "\e[1m"
	RESET = "\e[0m"
end

require 'blink_tm/version'
require 'blink_tm/blink_tm'
