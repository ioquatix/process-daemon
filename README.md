# Process::Daemon

`Process::Daemon` is a stable and helpful base class for long running tasks and daemons. Provides standard `start`, `stop`, `restart`, `status` operations.

[![Build Status](https://travis-ci.org/ioquatix/process-daemon.svg)](https://travis-ci.org/ioquatix/process-daemon)

## Installation

Add this line to your application's Gemfile:

    gem 'process-daemon'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install process-daemon

## Usage

Create a file for your daemon, e.g. `daemon.rb`:

	#!/usr/bin/env ruby
	
	require 'process/daemon'
	
	# Very simple XMLRPC daemon
	class XMLRPCDaemon < Process::Daemon
		def base_directory
			# Should be an absolute path:
			File.join(__dir__, "tmp")
		end
	
		def startup
			puts "Starting server..."
			
			@rpc_server = WEBrick::HTTPServer.new(
				:Port => 31337,
				:BindAddress => "0.0.0.0"
			)
			
			@listener = XMLRPC::WEBrickServlet.new
			
			@listener.add_handler("fourty-two") do |amount|
				"Hello World"
			end
			
			@rpc_server.mount("/RPC2", @listener)
			
			begin
				@rpc_server.start
			rescue Interrupt
				puts "Daemon interrupted..."
			ensure
				@rpc_server.shutdown
			end
		end
		
		def shutdown
			puts "Stopping the RPC server..."
			@rpc_server.stop
		end
	end
	
	XMLRPCDaemon.daemonize

Then run `daemon.rb start`. To stop the daemon, run `daemon.rb stop`.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
