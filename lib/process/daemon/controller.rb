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

require 'rainbow'

module Process
	class Daemon
		# Daemon startup timeout
		TIMEOUT = 5

		# This module contains functionality related to starting and stopping the @daemon, and code for processing command line input.
		class Controller
			# `options[:output]` specifies where to write textual output describing what is going on.
			def initialize(daemon, options = {})
				@daemon = daemon
				
				@output = options[:output] || $stdout
				
				# How long to wait until sending SIGTERM and eventually SIGKILL to the daemon process group when asking it to stop:
				@stop_timeout = options[:stop_timeout] || 10.0
			end
			
			# This function is called from the daemon executable. It processes ARGV and checks whether the user is asking for `start`, `stop`, `restart`, `status`.
			def daemonize(argv = ARGV)
				case argv.shift.to_sym
				when :start
					start
					status
				when :stop
					stop
					status
					ProcessFile.cleanup(@daemon)
				when :restart
					stop
					ProcessFile.cleanup(@daemon)
					start
					status
				when :status
					status
				else
					@stderr.puts Rainbow("Invalid command. Please specify start, restart, stop or status.").red
				end
			end
			
			# Fork a child process, detatch it and run the daemon code.
			def spawn
				@daemon.prefork
				@daemon.mark_log

				fork do
					Process.setsid
					exit if fork

					ProcessFile.store(@daemon, Process.pid)

					File.umask 0000
					Dir.chdir @daemon.working_directory

					$stdin.reopen "/dev/null"
					$stdout.reopen @daemon.log_file_path, "a"
					$stdout.sync = true
				
					$stderr.reopen $stdout
					$stderr.sync = true

					begin
						@daemon.run
					rescue Exception => error
						$stderr.puts "=== Daemon Exception Backtrace @ #{Time.now.to_s} ==="
						$stderr.puts "#{error.class}: #{error.message}"
						$!.backtrace.each { |at| $stderr.puts at }
						$stderr.puts "=== Daemon Crashed ==="
						$stderr.flush
					ensure
						$stderr.puts "=== Daemon Stopping @ #{Time.now.to_s} ==="
						$stderr.flush
					end
				end
			end

			# This function starts the daemon process in the background.
			def start
				@output.puts Rainbow("Starting #{@daemon.name} daemon...").blue

				case ProcessFile.status(@daemon)
				when :running
					@output.puts Rainbow("Daemon already running!").blue
					return
				when :stopped
					# We are good to go...
				else
					@output.puts Rainbow("Daemon in unknown state! Will clear previous state and continue.").red
					ProcessFile.clear(@daemon)
				end

				spawn

				sleep 0.1
				timer = TIMEOUT
				pid = ProcessFile.recall(@daemon)

				while pid == nil and timer > 0
					# Wait a moment for the forking to finish...
					@output.puts Rainbow("Waiting for daemon to start (#{timer}/#{TIMEOUT})").blue
					sleep 1

					# If the @daemon has crashed, it is never going to start...
					break if @daemon.crashed?

					pid = ProcessFile.recall(@daemon)

					timer -= 1
				end
			end
			
			# Prints out the status of the daemon
			def status
				daemon_state = ProcessFile.status(@daemon)
				
				case daemon_state
				when :running
					@output.puts Rainbow("Daemon status: running pid=#{ProcessFile.recall(@daemon)}").green
				when :unknown
					if @daemon.crashed?
						@output.puts Rainbow("Daemon status: crashed").red

						@output.flush
						@output.puts Rainbow("Dumping daemon crash log:").red
						@daemon.tail_log(@output)
					else
						@output.puts Rainbow("Daemon status: unknown").red
					end
				when :stopped
					@output.puts Rainbow("Daemon status: stopped").blue
				end
				
				return daemon_state
			end

			def pid
				ProcessFile.recall(@daemon)
			end

			# How long to wait between checking the daemon process when shutting down:
			STOP_PERIOD = 0.1

			# Stops the daemon process.
			def stop
				@output.puts Rainbow("Stopping #{@daemon.name} daemon...").blue

				# Check if the pid file exists...
				unless File.file?(@daemon.process_file_path)
					@output.puts Rainbow("Pid file not found. Is the daemon running?").red
					return
				end

				pid = ProcessFile.recall(@daemon)

				# Check if the @daemon is already stopped...
				unless ProcessFile.running(@daemon)
					@output.puts Rainbow("Pid #{pid} is not running. Has daemon crashed?").red

					@daemon.tail_log($stderr)

					return
				end

				# Interrupt the process group:
				pgid = -Process.getpgid(pid)
				Process.kill("INT", pgid)

				(@stop_timeout / STOP_PERIOD).to_i.times do
					sleep STOP_PERIOD if ProcessFile.running(@daemon)
				end

				# Kill/Term loop - if the @daemon didn't die easily, shoot
				# it a few more times.
				attempts = 5
				while ProcessFile.running(@daemon) and attempts > 0
					sig = (attempts <= 2) ? "KILL" : "TERM"

					@output.puts Rainbow("Sending #{sig} to process group #{pgid}...").red
					Process.kill(sig, pgid)

					attempts -= 1
					sleep 1
				end

				# If after doing our best the @daemon is still running (pretty odd)...
				if ProcessFile.running(@daemon)
					@output.puts Rainbow("Daemon appears to be still running!").red
					return
				end

				# Otherwise the @daemon has been stopped.
				ProcessFile.clear(@daemon)
			end
		end
	end
end
