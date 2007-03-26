require 'pty'
require 'expect'

fnames = []
PTY.spawn("telnet -l root agneyam.india.sun.com") do |read_pipe,write_pipe,pid|
    write_pipe.sync = true

    $expect_verbose = false
    read_pipe.expect(/^Password.*: /) do
        write_pipe.print "abc123\n"
    end

    read_pipe.expect(/agneyam#/) do
        write_pipe.print "uname -a\n"
    end
    read_pipe.expect(/[^#]+#/) do |output|
        for x in output[0].split("\n")
            #SunOS agneyam 5.10 Generic sun4u sparc SUNW,Sun-Blade-1000
            if x =~ /^([^ ]+) ([^ ]+) (.*)$/ then
                puts "#{$2} running #{$1}"
                return true
            end
        end
    end
    begin
        write_pipe.print "quit\n"
    rescue
    end
end

raise "failed for uname"
