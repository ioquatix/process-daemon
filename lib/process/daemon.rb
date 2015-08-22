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

require 'fileutils'

require_relative 'daemon/controller'

require_relative 'daemon/notification'

require_relative 'daemon/log_file'
require_relative 'daemon/process_file'

module Process
	# Provides the infrastructure for spawning a daemon.
	class Daemon
		# Initialize the daemon in the given working root.
		def initialize(working_directory = ".")
			@working_directory = working_directory
			
			@shutdown_notification = Notification.new
		end
		
		# Return the name of the daemon
		def name
			return self.class.name.gsub(/[^a-zA-Z0-9]+/, '-')
		end

		# The directory the daemon will run in.
		attr :working_directory

		# Return the directory to store log files in.
		def log_directory
			File.join(working_directory, "log")
		end

		# Standard log file for stdout and stderr.
		def log_file_path
			File.join(log_directory, "#{name}.log")
		end

		# Runtime data directory for the daemon.
		def runtime_directory
			File.join(working_directory, "run")
		end

		# Standard location of process pid file.
		def process_file_path
			File.join(runtime_directory, "#{name}.pid")
		end

		# Mark the output log.
		def mark_log
			File.open(log_file_path, "a") do |log_file|
				log_file.puts "=== Log Marked @ #{Time.now.to_s} [#{Process.pid}] ==="
			end
		end

		# Prints some information relating to daemon startup problems.
		def tail_log(output)
			lines = LogFile.open(log_file_path).tail_log do |line|
				line.match("=== Log Marked") || line.match("=== Daemon Exception Backtrace")
			end
			
			output.puts lines
		end

		# Check the last few lines of the log file to find out if the daemon crashed.
		def crashed?
			count = 3
			
			LogFile.open(log_file_path).tail_log do |line|
				return true if line.match("=== Daemon Crashed")

				break if (count -= 1) == 0
			end

			return false
		end
		
		# The main function to setup any environment required by the daemon
		def prefork
			# Ignore any previously setup signal handler for SIGINT:
			trap(:INT, :DEFAULT)
			
			# We update the working directory to a full path:
			@working_directory = File.expand_path(working_directory)
			
			FileUtils.mkdir_p(log_directory)
			FileUtils.mkdir_p(runtime_directory)
		end
		
		# The process title of the daemon.
		attr :title
		
		# Set the process title - only works after daemon has forked.
		def title= title
			@title = title
			
			if Process.respond_to? :setproctitle
				Process.setproctitle(@title)
			else
				$0 = @title
			end
		end
		
		# Request that the sleep_until_interrupted function call returns.
		def request_shutdown
			@shutdown_notification.signal
		end
		
		# Call this function to sleep until the daemon is sent SIGINT.
		def sleep_until_interrupted
			trap(:INT) do
				self.request_shutdown
			end

			@shutdown_notification.wait
		end
		
		# This function must setup the daemon quickly and return.
		def startup
		end
		
		# If you want to implement a long running process you override this method. You may like to call super but it is not necessary to use the supplied interruption machinery.
		def run
			sleep_until_interrupted
		end
		
		# This function should terminate any active processes in the daemon and return as quickly as possible.
		def shutdown
		end
		
		# The entry point from the newly forked process.
		def spawn
			self.title = self.name
			
			self.startup
			
			begin
				self.run
			rescue Interrupt
				$stderr.puts "Daemon interrupted, proceeding to shutdown."
			end
			
			self.shutdown
		end
		
		# A shared instance of the daemon.
		def self.instance
			@instance ||= self.new
		end
		
		# The process controller, responsible for managing the daemon process start, stop, restart, etc.
		def self.controller(options = {})
			@controller ||= Controller.new(instance, options)
		end
		
		# The main entry point for daemonized scripts.
		def self.daemonize(*args)
			# Wish Ruby 2.0 kwargs were backported to 1.9.3... oh well:
			options = (args.last === Hash) ? args.pop : {}
			argv = (args.last === Array) ? args.pop : ARGV
			
			controller(options).daemonize(argv)
		end
		
		# Start the shared daemon instance.
		def self.start
			controller.start
		end
		
		# Stop the shared daemon instance.
		def self.stop
			controller.stop
		end
		
		# Check if the shared daemon instance is runnning or not.
		def self.status
			controller.status
		end
	end
end
