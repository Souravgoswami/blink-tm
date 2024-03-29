#!/usr/bin/env ruby
# Frozen_String_Literal: true

module BlinkTM
	# Detect device
	def find_device
		Dir.glob('/sys/bus/usb/devices/*').each { |x|
			v = File.join(x, 'idVendor')
			vendor = IO.read(v).strip if File.readable?(v)

			p = File.join(x, 'idProduct')
			product = IO.read(p).strip if File.readable?(p)

			if vendor == '1a86' && product == '7523'
				log 'warn', "A potential device discovered: #{vendor}:#{product}"

				Dir.glob('/dev/ttyUSB[0-9]*').each { |x|
					if File.writable?(x)
						log 'success', "Changing baudrate to 57600..."

						if BlinkTM.set_baudrate(x, BlinkTM::BAUDRATE)
							log 'success', 'Successfully Changed baudrate to 57600...'
						else
							log 'error', 'Cannot change the baudrate'
						end
					else
						log 'error', 'No permission granted to change Baudrate'
					end

					if File.readable?(x)
						begin
							return x if File.open(x).read_nonblock(30).to_s.scrub.include?("BTM")
						rescue EOFError
							sleep 0.05
							retry
						rescue Errno::ENOENT, Errno::EIO
						end
					end
				}
			end
		}

		nil
	end

	@@retry_count = 0
	def find_device!
		while(!(dev = BlinkTM.find_device))
			log 'error', "No device found. Retrying #{@@retry_count += 1}"
			sleep 0.5
		end

		log 'success', "Device discovered successfully. Path: #{dev}#{BlinkTM::RESET}"
		dev
	end

	# Convert Numeric bytes to the format that blink-taskmanager can read
	def convert_bytes(n)
		if n >= TB
			"%06.2f".%(n.fdiv(TB)).split(?.).join + ?4
		elsif n >= GB
			"%06.2f".%(n.fdiv(GB)).split(?.).join + ?3
		elsif n >= MB
			"%06.2f".%(n.fdiv(MB)).split(?.).join + ?2
		elsif n >= KB
			"%06.2f".%(n.fdiv(KB)).split(?.).join + ?1
		else
			"%06.2f".%(n).split(?.).join + ?0
		end
	end

	# Convert percentages to the format that blink-taskmanager can read
	def convert_percent(n)
		"%06.2f".%(n).split('.').join
	end

	def start(device, daylight_checker_options)
		return false unless device

		latitude, longitude = daylight_checker_options[:latitude]&.to_f, daylight_checker_options[:longitude]&.to_f
		log 'success', "Set latitude to #{latitude}, longitude to #{longitude}" if !latitude.nil? && !longitude.nil?

		cpu_u = mem_u = swap_u = iostat = net_u = net_d = 0
		io_r = io_w = 0
		built_in_led_state = 0

		Thread.new {
			while true
				_cpu_u = LS::CPU.total_usage(POLLING).to_f
				cpu_u = _cpu_u.nan? ? 255 : _cpu_u.to_i
			end
		}

		Thread.new {
			while true
				netstat = LS::Net::current_usage(POLLING)
				net_u = netstat[:transmitted].to_i
				net_d = netstat[:received].to_i
			end
		}

		Thread.new {
			while true
				io_stat1 = LS::FS.total_io(ROOT)
				sleep POLLING
				io_stat2 = LS::FS.total_io(ROOT)

				io_r = io_stat2[0].-(io_stat1[0]).*(SECTORS).fdiv(POLLING)
				io_w = io_stat2[1].-(io_stat1[1]).*(SECTORS).fdiv(POLLING)
			end
		}

		prev_crc32 = ''
		prev_time = { min: -1, hour: -1 }
		raise NoDeviceError unless device

		in_sync = false

		fd = IO.sysopen(
			device,
			Fcntl::O_RDWR | Fcntl::O_NOCTTY | Fcntl::O_NONBLOCK | Fcntl::O_TRUNC
		)

		file = IO.open(fd)
		yield file

		until in_sync
			# Clear out any extra zombie bits
			file.syswrite(?~.freeze)
			# Start the device
			file.syswrite(?#.freeze)
			file.flush

			sleep 0.125

			begin
				if file.read_nonblock(8000).include?(?~)
					in_sync = true
					break
				end
			rescue EOFError
				sleep 0.05
				retry
			end
		end

		sync_error_count = 0

		log 'success', 'Device ready!'
		file.read

		while true
			# cpu(01234) memUsed(999993) swapUsed(999992) io_active(0)
			# netUpload(999991) netDownload(999990)
			# disktotal(999990) diskused(999990)

			memstat = LS::Memory.stat
			_mem_u = memstat[:used].to_i.*(1024).*(100).fdiv(memstat[:total].to_i * 1024)
			mem_u = _mem_u.nan? ? 255 : _mem_u.round

			swapstat = LS::Swap.stat
			_swap_u = swapstat[:used].to_i.*(1024).*(100).fdiv(swapstat[:total].to_i * 1024)
			swap_u = _swap_u.nan? ? 255 : _swap_u.round

			time_minute = Time.now.min
			time_hour = Time.now.hour

			if (time_minute != prev_time[:min] || time_hour != prev_time[:hour]) && !latitude.nil? && !longitude.nil?
				dark_outside = DaylightChecker.new(
					latitude,
					longitude,
					Time.now
				).is_it_dark?

				built_in_led_state = dark_outside ? 1 : 0

				prev_time[:min] = time_minute
				prev_time[:hour] = time_hour
			end

			# Output has to be exactly this long. If not, blink-taskmanager shows invalid result.
			# No string is split inside blink-task manager, it just depends on the string length.
			#
			# cpu(100) memUsed(100) swapUsed(100)
			# netDownload(9991) netUpload(9991)
			# ioWrite(9991) ioRead(9991)

			# Debugging string
			# str = "#{"%03d" % cpu_u} #{"%03d" % mem_u} #{"%03d" % swap_u} "\
			# "#{convert_bytes(net_u)} #{convert_bytes(net_d)} "\
			# "#{convert_bytes(io_r)} #{convert_bytes(io_w)}"

			str = "!##{"%03d" % cpu_u}#{"%03d" % mem_u}#{"%03d" % swap_u}"\
			"#{convert_bytes(net_u)}#{convert_bytes(net_d)}"\
			"#{convert_bytes(io_r)}#{convert_bytes(io_w)}#{built_in_led_state}1~"

			# Rescuing from suspend
			file.syswrite(str)
			file.flush
			crc32 = file.read.scrub![/\d+/]

			unless crc32 == prev_crc32 || prev_crc32.empty?
				raise SyncError if sync_error_count > 1
				sync_error_count += 1
			else
				sync_error_count = 0 unless sync_error_count == 0
			end

			prev_crc32 = BlinkTM.crc32(str[2..-2])
			sleep REFRESH
		end

		unless device
			puts "#{BlinkTM::BOLD}#{BlinkTM::RED}:: #{Time.now.strftime('%H:%M:%S.%2N')}: Error establishing connection. Don't worry if this is a valid device. Retrying...#{BlinkTM::RESET}"
			sleep 0.1
		end
	end

	def log(type, message = nil)
		message, type = type, nil if type && !message

		colour = case type
			when 0, 'fatal', 'error' then BlinkTM::RED
			when 1, 'warn' then BlinkTM::ORANGE
			when 2, 'info' then BlinkTM::BLUE
			when 3, 'success', 'ok' then BlinkTM::GREEN
			else ''
		end

		puts "#{BlinkTM::BOLD}#{colour}:: #{Time.now.strftime('%H:%M:%S.%2N')}: #{message}#{BlinkTM::RESET}"
	end

	extend(self)
end
