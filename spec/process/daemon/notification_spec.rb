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

require 'process/daemon/notification'

module Process::Daemon::NotificationSpec
	describe Process::Daemon::Notification do
		it "can be signalled multiple times" do
			notification = Process::Daemon::Notification.new
			
			expect(notification.signalled?).to be_falsey
			
			notification.signal
			
			expect(notification.signalled?).to be_truthy
			
			notification.signal
			notification.signal
			
			expect(notification.signalled?).to be_truthy
		end
		
		it "can be signalled within trap context and across processes" do
			ready = Process::Daemon::Notification.new
			notification = Process::Daemon::Notification.new
			
			pid = fork do
				trap(:INT) do
					notification.signal
					exit(0)
				end
				
				ready.signal
				
				sleep
			end
			
			ready.wait(timeout: 5.0)
			
			Process.kill(:INT, pid)
			
			notification.wait(timeout: 1.0)
			
			expect(notification.signalled?).to be_truthy
			
			# Clean up zombie process
			Process.waitpid(pid)
		end
		
		it "should receive signal in child process" do
			notification = Process::Daemon::Notification.new
			
			pid = fork do
				if notification.wait(timeout: 60)
					exit(0)
				else
					exit(1)
				end
			end
			
			notification.signal
			
			Process.waitpid(pid)
			
			expect($?.exitstatus).to be == 0
		end
		
		it "should not receive signal in child process and time out" do
			notification = Process::Daemon::Notification.new
			
			pid = fork do
				if notification.wait(timeout: 0.01)
					exit(0)
				else
					exit(1)
				end
			end
			
			Process.waitpid(pid)
			
			expect($?.exitstatus).to be == 1
		end
	end
end
