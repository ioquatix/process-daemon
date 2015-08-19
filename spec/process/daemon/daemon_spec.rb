# Copyright, 2007, 2014, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

require 'process/daemon'

require 'webrick'
require 'webrick/https'

require 'xmlrpc/server'
require 'xmlrpc/client'

module Process::Daemon::DaemonSpec
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

			@listener.add_handler("add") do |amount|
				@count ||= 0
				@count += amount
			end

			@listener.add_handler("total") do
				@count
			end

			@rpc_server.mount("/RPC2", @listener)
		end
		
		def run
			# This is the correct way to cleanly shutdown the server, apparently:
			trap(:INT) do
				@rpc_server.shutdown
			end
			
			puts "RPC server starting..."
			@rpc_server.start
		ensure
			puts "Stop accepting new connections to RPC server..."
			@rpc_server.shutdown
		end
	end

	class SleepDaemon < Process::Daemon
		def working_directory
			File.expand_path("../tmp", __FILE__)
		end

		def run
			sleep 1 while true
		end
	end

	describe Process::Daemon do
		before do
			XMLRPCDaemon.start
		end
		
		after do
			XMLRPCDaemon.stop
		end
		
		it "should be running" do
			expect(XMLRPCDaemon.status).to be == :running
		end
		
		it "should respond to connections" do
			rpc = XMLRPC::Client.new_from_uri("http://localhost:31337")
			rpc.call("add", 10)

			total = rpc.call("total")
			
			expect(total).to be == 10
		end
		
		it "should be a unique instance" do
			expect(XMLRPCDaemon.instance).to_not be == SleepDaemon.instance
		end
		
		it "should produce useful output" do
			output = StringIO.new
			
			controller = Process::Daemon::Controller.new(XMLRPCDaemon.instance, :output => output)
			
			expect(controller.status).to be == :running
			
			expect(output.string).to match /Daemon status: running pid=\d+/
			
			output.rewind
			controller.stop
			
			expect(output.string).to match /Stopping/
			
			output.rewind
			controller.start
			
			expect(output.string).to match /Starting/
		end
		
		it "should have correct process title" do
			pid = XMLRPCDaemon.controller.pid
			
			title = `ps -p #{pid} -o command=`.strip
			
			expect(title).to match /XMLRPCDaemon/
		end
	end
end
