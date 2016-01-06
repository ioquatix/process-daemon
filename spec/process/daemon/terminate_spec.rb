# Copyright, 2014, by Samuel G. D. Williams. <http://www.codeotaku.com>
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
require 'process/daemon/process_file'

module Process::Daemon::TerminateSpec
	class SleepDaemon < Process::Daemon
		def working_directory
			File.expand_path("../tmp", __FILE__)
		end

		def startup
			setup_signals
		end
		
		def setup_signals
			trap('INT') do
				puts 'INT'
			end
			
			trap('TERM') do
				puts 'TERM'
			end
		end

		def run
			sleep 1 while true
		end
	end

	describe Process::Daemon do
		let(:daemon) {SleepDaemon.instance}
		let(:controller) {Process::Daemon::Controller.new(daemon)}
		
		# Print out the daemon log file:
		#after(:each) do
		#	system('cat', daemon.log_file_path)
		#end
		
		it "should be killed" do
			controller.start
			
			expect(controller.status).to be == :running
			
			controller.stop
			
			expect(controller.status).to be == :stopped
			
			output = File.readlines(daemon.log_file_path).last(6)
			expect(output).to be == ["INT\n", "TERM\n", "TERM\n", "TERM\n", "TERM\n", "TERM\n"]
		end
	end
end
