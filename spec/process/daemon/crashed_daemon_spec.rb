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

module Process::Daemon::DaemonizeSpec
	class CrashDaemon < Process::Daemon
		def working_directory
			File.expand_path("../tmp", __FILE__)
		end
		
		def run
			and_bobs_your_uncle
		end
	end

	describe Process::Daemon do
		it "should crash daemon and print exception" do
			output = StringIO.new
			
			controller = Process::Daemon::Controller.new(CrashDaemon.instance, :output => output)
			
			controller.start
			
			sleep 1
			
			controller.show_status
			
			expect(CrashDaemon.status).to be == :unknown
			expect(output.string).to include("=== Daemon Exception Backtrace", "=== Daemon Crashed")
			expect(output.string).to include("NameError", "and_bobs_your_uncle")
		end
	end
end
