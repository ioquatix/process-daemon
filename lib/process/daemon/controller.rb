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
				case (argv.shift || :default).to_sym
				when :start
					start
					show_status
				when :stop
					stop
					show_status
					ProcessFile.cleanup(@daemon)
				when :restart
					stop
					ProcessFile.cleanup(@daemon)
					start
					show_status
				when :status
					show_status
				else
					@output.puts Rainbow("Invalid command. Please specify start, restart, stop or status.").red
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

					$stdin.reopen '/dev/null'
					$stdout.reopen @daemon.log_file_path, 'a'
					$stdout.sync = true
				
					$stderr.reopen $stdout
					$stderr.sync = true

					begin
						@daemon.spawn
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

				case self.status
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
				ProcessFile.status(@daemon)
			end
			
			def show_status
				case self.status
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
			end
			
			# The pid of the daemon if it is available. The pid may be invalid if the daemon has crashed.
			def pid
				ProcessFile.recall(@daemon)
			end

			# How long to wait between checking the daemon process when shutting down:
			STOP_PERIOD = 0.1
			
			# The number of attempts to stop the daemon using SIGTERM. On the last attempt, SIGKILL is used.
			STOP_ATTEMPTS = 5
			
			# The factor which controls how long we sleep between attempts to kill the process. Only applies to processes which don't stop immediately.
			STOP_WAIT_FACTOR = 3.0

			# Stops the daemon process. This function initially sends SIGINT. It waits STOP_PERIOD and checks if the daemon is still running. If it is, it sends SIGTERM, and then waits a bit longer. It tries STOP_ATTEMPTS times until it basically assumes the daemon is stuck and sends SIGKILL.
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

				pgid = -Process.getpgid(pid)

				unless stop_by_interrupt(pgid)
					stop_by_terminate_or_kill(pgid)
				end

				# If after doing our best the @daemon is still running (pretty odd)...
				if ProcessFile.running(@daemon)
					@output.puts Rainbow("Daemon appears to be still running!").red
					return
				else
					@output.puts Rainbow("Daemon has left the building.").green
				end

				# Otherwise the @daemon has been stopped.
				ProcessFile.clear(@daemon)
			end
			
			private
			
			def stop_by_interrupt(pgid)
				running = true
				
				# Interrupt the process group:
				Process.kill("INT", pgid)

				(@stop_timeout / STOP_PERIOD).ceil.times do
					if running = ProcessFile.running(@daemon)
						sleep STOP_PERIOD
					end
				end
				
				return running
			end
			
			def stop_by_terminate_or_kill(pgid)
				# TERM/KILL loop - if the daemon didn't die easily, shoot it a few more times.
				(STOP_ATTEMPTS+1).times do |attempt|
					break unless ProcessFile.running(@daemon)

					# SIGKILL gets sent on the last attempt.
					signal_name = (attempt < STOP_ATTEMPTS) ? "TERM" : "KILL"

					@output.puts Rainbow("Sending #{signal_name} to process group #{pgid}...").red

					Process.kill(signal_name, pgid)

					# We iterate quickly to start with, and slow down if the process seems unresponsive.
					timeout = STOP_PERIOD + (attempt.to_f / STOP_ATTEMPTS) * STOP_WAIT_FACTOR
					@output.puts Rainbow("Waiting for #{timeout.round(1)}s for daemon to terminate...").blue
					sleep(timeout)
				end
			end
		end
	end
end
