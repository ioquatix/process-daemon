# Copyright, 2015, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

module Process
	class Daemon
		# This is a one shot cross-process notification mechanism using pipes. It can also be used in the same process if required, e.g. the self-pipe trick.
		class Notification
			def initialize
				@output, @input = IO.pipe
				
				@signalled = false
			end
			
			# Signal the notification.
			def signal
				@signalled = true
				
				@input.puts
			end
			
			# Was this notification signalled?
			def signalled?
				@signalled
			end
			
			# Wait/block until a signal is received. Optional timeout.
			# @param timeout [Integer] the time to wait in seconds.
			def wait(timeout: nil)
				if timeout
					read_ready, _, _ = IO.select([@output], [], [], timeout)
					
					return false unless read_ready and read_ready.any?
				end
				
				@signalled or @output.read(1)
				
				# Just in case that this was split across multiple processes.
				@signalled = true
			end
		end
	end
end
