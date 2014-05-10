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

module Process
	class Daemon
		class LogFile < File
			# Yields the lines of a log file in reverse order, once the yield statement returns true, stops, and returns the lines in order.
			def tail_log
				lines = []

				seek_end
				
				reverse_each_line do |line|
					lines << line
					
					break if yield line
				end

				return lines.reverse
			end
			
			private
			
			# Seek to the end of the file
			def seek_end(offset = 0)
				seek(offset, IO::SEEK_END)
			end
	
			# Read a chunk of data and then move the file pointer backwards.
			#
			# Calling this function multiple times will return new data and traverse the file backwards.
			#
			def read_reverse(length)
				offset = tell

				if offset == 0
					return nil
				end

				start = [0, offset-length].max

				seek(start, IO::SEEK_SET)

				buf = read(offset-start)

				seek(start, IO::SEEK_SET)

				return buf
			end

			REVERSE_BUFFER_SIZE = 128

			# This function is very similar to gets but it works in reverse.
			#
			# You can use it to efficiently read a file line by line backwards.
			# 
			# It returns nil when there are no more lines.
			def reverse_gets(sep_string=$/)
				end_pos = tell

				offset = nil
				buf = ""

				while offset == nil
					chunk = read_reverse(REVERSE_BUFFER_SIZE)
					return (buf == "" ? nil : buf) if chunk == nil

					buf = chunk + buf

					offset = buf.rindex(sep_string)
				end

				line = buf[offset...buf.size].sub(sep_string, "")

				seek((end_pos - buf.size) + offset, IO::SEEK_SET)

				return line
			end

			# Similar to each_line but works in reverse. Don't forget to call
			# seek_end before you start!
			def reverse_each_line(sep_string=$/, &block)
				return to_enum(:reverse_each_line) unless block_given?
		
				line = reverse_gets(sep_string)

				while line != nil
					yield line

					line = reverse_gets(sep_string)
				end
			end
		end
	end
end
