# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'process/daemon/version'

Gem::Specification.new do |spec|
	spec.name          = "process-daemon"
	spec.version       = Process::Daemon::VERSION
	spec.authors       = ["Samuel Williams"]
	spec.email         = ["samuel.williams@oriontransfer.co.nz"]
	spec.summary       = %q{`Process::Daemon` is a stable and helpful base class for long running tasks and daemons. Provides standard `start`, `stop`, `restart`, `status` operations.}
	spec.homepage      = "https://github.com/ioquatix/process-daemon"
	spec.license       = "MIT"
	spec.has_rdoc      = "yard"

	spec.files         = `git ls-files`.split($/)
	spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
	spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
	spec.require_paths = ["lib"]
	
	spec.required_ruby_version = '>= 1.9.3'
	
	spec.add_dependency "rainbow", "~> 2.0"
	
	spec.add_development_dependency "bundler", "~> 1.3"
	spec.add_development_dependency "rspec", "~> 3.4.0"
	spec.add_development_dependency "rake"
end
