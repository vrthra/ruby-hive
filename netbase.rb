class NetBase
    def initialize(argv)
        argv.each {|arg|
            case arg.strip
            when /^-d$/
                $daemonize = true
            when /^-v$/
                $verbose = 1
            end
        }
        #check if we have a $base
        if $base.nil?
            #the last entry in $: is the $base use it and add our additional libs.
            update_cache($:.last)
        else
            if $base.instance_of? Array
                $base.each {|b| update_cache(b)}
            else
                update_cache($base)
            end
        end
    end
    def update_cache(b)
        base = b
        base << '/' unless base =~ /\/$/
        $: << "#{base}external"
    end
    def carp(str)
        puts str if $verbose > 0
    end
    def detach
        exit if fork
        Process.setsid
        exit if fork
        STDIN.reopen "/dev/null"
        #STDOUT.reopen "/dev/null", "a"
        STDOUT.reopen "pat.log", "a"
        STDERR.reopen STDOUT
    end
    def run
        if RUBY_PLATFORM =~ /mswin32/
            require 'external/win32/process'
            #fork and be a watchdog
            while true
                begin
                pid = fork do
                    begin
		        yield
                    rescue Exception => e
                        carp "fork:" + e.message
                        puts e.backtrace.join("\n") if $verbose
                    end
                end
                carp "pid:#{pid}"
                Process.waitpid2 pid
                carp "died[#{pid}]."
                sleep 2
                rescue Interrupt
                    carp "killing #{pid}"
                    Process.kill('SIGHUP', pid)
                    Process.wait
                    exit 0
                end
            end
        else
            #loose our terminal
            detach() if $daemonize
            #fork and be a watchdog
            while true
                begin
                    pid = fork do
                        begin
			    yield
                        rescue Exception => e
                            carp "fork:"+e.message
                            puts e.backtrace.join("\n") if $verbose
                        end
                    end
                    puts "after fork"
                    carp "pid:#{pid}"
                    Process.wait
                    carp "died[#{pid}]."
                    sleep 2
                rescue Interrupt
                    carp "killing #{pid}"
                    Process.kill('SIGHUP', pid)
                    Process.wait
                    exit 0
                end
            end
        end
    end
end
