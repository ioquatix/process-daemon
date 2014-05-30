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

module Process::Daemon::ProcessFileSpec
	class SleepDaemon < Process::Daemon
		def working_directory
			File.expand_path("../tmp", __FILE__)
		end

		def startup
			sleep 1 while true
		end
	end

	describe Process::Daemon::ProcessFile do
		let(:daemon) {SleepDaemon.instance}
		
		it "should save pid" do
			Process::Daemon::ProcessFile.store(daemon, $$)
			
			expect(Process::Daemon::ProcessFile.recall(daemon)).to be == $$
		end
		
		it "should clear pid" do
			Process::Daemon::ProcessFile.clear(daemon)
			
			expect(Process::Daemon::ProcessFile.recall(daemon)).to be nil
		end
		
		it "should be running" do
			Process::Daemon::ProcessFile.store(daemon, $$)
			
			expect(Process::Daemon::ProcessFile.status(daemon)).to be :running
		end
		
		it "should not be running" do
			Process::Daemon::ProcessFile.clear(daemon)
			
			expect(Process::Daemon::ProcessFile.status(daemon)).to be :stopped
		end
	end
end
