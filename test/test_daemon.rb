#!/usr/bin/env ruby

# Copyright (c) 2007, 2009, 2011 Samuel G. D. Williams. <http://www.oriontransfer.co.nz>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require 'minitest/autorun'

require 'process/daemon'

require 'webrick'
require 'webrick/https'

require 'xmlrpc/server'
require 'xmlrpc/client'

# Very simple XMLRPC daemon
class XMLRPCDaemon < Process::Daemon
	def working_directory
		File.join(__dir__, "tmp")
	end
	
	def startup
		puts "Starting server..."

		@rpc_server = WEBrick::HTTPServer.new(
			:Port => 31337,
			:BindAddress => "0.0.0.0"
		)

		@listener = XMLRPC::WEBrickServlet.new

		@listener.add_handler("add") do |amount|
			@count ||= 0
			@count += amount
		end

		@listener.add_handler("total") do
			@count
		end

		@rpc_server.mount("/RPC2", @listener)

		begin
			puts "Daemon starting..."
			@rpc_server.start
			puts "Daemon stopping..."
		rescue Interrupt
			puts "Daemon interrupted..."
		ensure
			puts "Daemon shutdown..."
			@rpc_server.shutdown
		end
	end

	def shutdown
		puts "Stopping the RPC server..."
		@rpc_server.stop
	end
end

class SleepDaemon < Process::Daemon
	def working_directory
		File.join(__dir__, "tmp")
	end

	def startup
		sleep 1 while true
	end
end

class DaemonTest < MiniTest::Test
	def setup
		XMLRPCDaemon.start
	end

	def teardown
		XMLRPCDaemon.stop
	end

	def test_connection
		rpc = XMLRPC::Client.new_from_uri("http://localhost:31337")
		rpc.call("add", 10)

		total = rpc.call("total")

		assert_equal 10, total
	end
	
	def test_instances
		refute_equal SleepDaemon.instance, XMLRPCDaemon.instance
	end
	
	def test_output
		output = StringIO.new
		
		controller = Process::Daemon::Controller.new(XMLRPCDaemon.instance, :output => output)
		
		assert_equal :running, controller.status
		
		assert_match /Daemon status: running pid=\d+/, output.string
		
		output.rewind
		controller.stop
		
		assert_match /Stopping/, output.string
		
		output.rewind
		controller.start
		
		assert_match /Starting/, output.string
	end
	
	def test_process_title
		pid = XMLRPCDaemon.controller.pid
		
		title = `ps -p #{pid} -o command=`.strip
		
		assert_match /XMLRPCDaemon/, title
	end
end
