
#!/usr/bin/ruby -w
# Frozen_String_Literal: true

require 'fcntl'
require 'linux_stat'

module BlinkTM
	# Detect device
	def find_device
		dev = nil

		Dir.glob('/sys/bus/usb/devices/*').each { |x|
			v = File.join(x, 'idVendor')
			vendor = IO.read(v).strip if File.readable?(v)

			p = File.join(x, 'idProduct')
			product = IO.read(p).strip if File.readable?(p)

			if vendor == '1a86' && product == '7523'
				puts "#{BOLD}#{GREEN}:: #{Time.now.strftime('%H:%M:%S.%2N')}: A potential device discovered: #{vendor}:#{product}#{RESET}"

				Dir.glob('/dev/ttyUSB[0-9]*').each { |x|
					if File.writable?(x)
						puts "#{BlinkTM::BOLD}#{BlinkTM::BLUE}:: #{Time.now.strftime('%H:%M:%S.%2N')}: Changing baudrate to 57600...#{BlinkTM::RESET}"

						if BlinkTM.set_baudrate(x, BlinkTM::BAUDRATE)
							puts "#{BlinkTM::BOLD}#{BlinkTM::GREEN}:: #{Time.now.strftime('%H:%M:%S.%2N')}: Successfully Changed baudrate to 57600...#{BlinkTM::RESET}"
						else
							puts "#{BlinkTM::BOLD}#{BlinkTM::RED}:: #{Time.now.strftime('%H:%M:%S.%2N')}: Cannot change the baudrate#{BlinkTM::RESET}"
						end
					else
						"#{BOLD}#{RED}:: #{Time.now.strftime('%H:%M:%S.%2N')}: No permission granted to change Baudrate#{RESET}"
					end

					if File.readable?(x)
						if File.open(x).readpartial(30).to_s.scrub.include?("BTM")
							puts "#{BOLD}#{ORANGE}:: #{Time.now.strftime('%H:%M:%S.%2N')}: Multiple Blink Task "\
							"Manager Hardware Found! "\
							"Selecting: #{vendor}:#{product}#{RESET}" if dev

							dev = x
						end
					end
				}
			end
		}

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

	def start(device)
		return false unless device

		cpu_u = mem_u = swap_u = iostat = net_u = net_d = 0
		io_r = io_w = 0

		Thread.new {
			cpu_u = LS::CPU.total_usage(POLLING).to_f while true
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
				io_stat1 = iostat()
				sleep POLLING
				io_stat2 = iostat()

				io_r = io_stat2[0] - io_stat1[0]
				io_w = io_stat2[1] - io_stat1[1]
			end
		}

		begin
			raise NoDeviceError unless device

			in_sync = false
			fd = IO.sysopen(device, Fcntl::O_RDWR | Fcntl::O_EXCL)
			file = IO.open(fd)

			until in_sync
				file.syswrite(?#)
				file.flush

				begin
					if file.readpartial(8000).include?(?~)
						in_sync = true
						break
					end
				rescue EOFError
					sleep 0.05
					retry
				end

				sleep 0.05
			end

			puts "#{BlinkTM::BOLD}#{BlinkTM::GREEN}:: #{Time.now.strftime('%H:%M:%S.%2N')}: Device ready!#{BlinkTM::RESET}"

			while true
				# cpu(01234) memUsed(999993) swapUsed(999992) io_active(0)
				# netUpload(999991) netDownload(999990)
				# disktotal(999990) diskused(999990)

				memstat = LS::Memory.stat
				mem_u = memstat[:used].to_i.*(1024).*(100).fdiv(memstat[:total].to_i * 1024).round

				swapstat = LS::Swap.stat
				swap_u = swapstat[:used].to_i.*(1024).*(100).fdiv(swapstat[:total].to_i * 1024).round

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

				str = "#{"%03d" % cpu_u}#{"%03d" % mem_u}#{"%03d" % swap_u}"\
				"#{convert_bytes(net_u)}#{convert_bytes(net_d)}"\
				"#{convert_bytes(io_r)}#{convert_bytes(io_w)}"

				file.syswrite('!')
				file.flush
				sleep 0.025

				file.syswrite(str)
				file.flush
				sleep 0.025

				file.syswrite('~')
				file.flush

				sleep REFRESH
			end
		rescue Interrupt, SystemExit, SignalException
			file &.close
			exit 0
		rescue Errno::ENOENT, BlinkTM::NoDeviceError
			device = find_device

			unless device
				puts "#{BlinkTM::BOLD}#{BlinkTM::RED}:: #{Time.now.strftime('%H:%M:%S.%2N')}: Error establishing connection. Don't worry if this is a valid device. Retrying...#{BlinkTM::RESET}"
				sleep 0.1
			end

			retry
		rescue Exception
			puts $!.full_message
			file &.close
			sleep 0.1
			retry
		end
	end

	def iostat
		@@root_partition ||= IO.foreach('/proc/mounts').detect {
			|x| x.split[1] == ?/
		}.to_s.split[0].to_s.split(?/).to_a[-1]

		@@sector_size = LS::FS.stat(?/)[:block_size]

		io_stat = IO.foreach('/proc/diskstats'.freeze).find { |x|
			x.split[2] == @@root_partition
		} &.split.to_a

		_io_r = io_stat[5].to_f.*(@@sector_size).round
		_io_w = io_stat[9].to_f.*(@@sector_size).round

		[_io_r, _io_w]
	end

	extend(self)
end