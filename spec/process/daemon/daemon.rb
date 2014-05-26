#!/usr/bin/env ruby

require 'process/daemon'

require 'webrick'
require 'webrick/https'

require 'xmlrpc/server'

# Very simple XMLRPC daemon
class XMLRPCDaemon < Process::Daemon
	def working_directory
		File.expand_path("../tmp", __FILE__)
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
