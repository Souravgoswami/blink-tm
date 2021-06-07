# frozen_string_literal: true
require_relative "lib/blink_tm/version"

Gem::Specification.new do |s|
	s.name = "blink_tm"
  s.version = BlinkTM::VERSION
	s.authors = ["Sourav Goswami"]
	s.email = ["souravgoswami@protonmail.com"]
	s.summary = "A controller for Arduino OLED System Monitor, Blink Task Manager"
	s.description = s.summary
	s.homepage = "https://github.com/souravgoswami/blink-tm"
	s.license = "MIT"
	s.required_ruby_version = Gem::Requirement.new(">= 2.6.0")
	s.files = Dir.glob(%w(exe/** ext/**/*.{c,h} lib/**/*.rb))
	s.executables = s.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
	s.require_paths = ["lib"]
	s.extensions = Dir.glob("ext/**/extconf.rb")
	s.bindir = "exe"
	s.add_runtime_dependency 'linux_stat', '>= 2.3.0'
end
