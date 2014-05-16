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

require_relative 'daemon/log_file'
require_relative 'daemon/process_file'

module Process
	# This class is the base daemon class. If you are writing a daemon, you should inherit from this class.
	#
	# The basic structure of a daemon is as follows:
	# 	
	# 	class Server < Process::Daemon
	# 		def startup
	# 			# Long running process, e.g. web server, game server, etc.
	# 		end
	# 		
	# 		def shutdown
	# 			# Stop the process above, usually called on SIGINT.
	# 		end
	# 	end
	# 	
	# 	Server.daemonize
	#
	# The base directory specifies a path such that:
	#   working_directory = "."
	#   log_directory = #{working_directory}/log
	#   log_file_path = #{log_directory}/#{daemon_name}.log
	#   runtime_directory = #{working_directory}/run
	#   process_file_path = #{runtime_directory}/#{daemon_name}.pid
	class Daemon
		def initialize(working_directory = ".")
			@working_directory = working_directory
		end
		
		# Return the name of the daemon
		def daemon_name
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
			File.join(log_directory, "#{daemon_name}.log")
		end

		# Runtime data directory for the daemon.
		def runtime_directory
			File.join(working_directory, "run")
		end

		# Standard location of process pid file.
		def process_file_path
			File.join(runtime_directory, "#{daemon_name}.pid")
		end

		# Mark the output log.
		def mark_log
			File.open(log_file_path, "a") do |log_file|
				log_file.puts "=== Log Marked @ #{Time.now.to_s} ==="
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
			# We freeze the working directory because it can't change after forking:
			@working_directory = File.expand_path(working_directory)
			
			def self.working_directory
				@working_directory
			end
			
			FileUtils.mkdir_p(log_directory)
			FileUtils.mkdir_p(runtime_directory)
		end

		# The main function to start the daemon
		def startup
		end

		# The main function to stop the daemon
		def shutdown
			# Interrupt all children processes, preferably to stop them so that they are not left behind.
			Process.kill(0, :INT)
		end
		
		def run
			trap("INT") do
				shutdown
			end
			
			startup
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
		
		# Start the daemon instance.
		def self.start
			controller.start
		end
		
		# Stop the daemon instance.
		def self.stop
			controller.stop
		end
		
		# Check if the daemon is runnning or not.
		def self.status
			controller.status
		end
	end
end
