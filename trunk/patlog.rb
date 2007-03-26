module Patlog
    #=======debug==========
    #showbt
    $gopt ||= {}
    #=======debug==========
    class Log
        def useopt(options)
            @options = options
        end
        def out(arg)
            if $gopt['showxchars']
                p arg
            else
                puts arg
            end
        end
        def o(arg)
            puts arg
        end
        def v(num)
            return true if @options.verbose > num
        end
        def cr(cr)
            out "cr:#{cr}" if v(3)
        end
        def title(title)
            out "[#{title}]" if v(3)
        end
        def show(info)
            out info
        end
        def cause(arg)
            out "Cause: " + arg
        end
        def fail(fail)
            out "Error: " + fail
        end
        def error(fail)
            out "Fatal: " + fail
        end
        def info(info)
            out info if v(0)
        end
        def verbose(info)
            out info if v(10)
        end
        def bt(err)
            if $gopt['showbt']
                out err.backtrace.join("\n")
            end
        end
        def dmatch(str)
            if $gopt['showdelimmatch']
                out "(#{str})"
            end
        end
        def matchlines(str)
            if $gopt['showmatch']
                out str
            end
        end
        def debug(str)
            if $gopt['showdebug']
                out str
            end
        end
        def response(data)
            if $gopt['showdebug'] && !data.nil?
                o "\n>===========>"
                data.each {|str|
                    out "#{str}"
                }
                o "\n>===========>"
            end
        end
        def request(data)
            if $gopt['showdebug'] && !data.nil?
                o "\n<===========<"
                data.each {|str|
                    out "#{str}"
                }
                o "\n<===========<"
            end
        end
        def die(info, exit_code)
            out info
            exit exit_code
        end
        def showtime(t)
            out "Time taken: #{t} seconds" if $gopt['showtime']
        end
    end

    class StdoutLog < Log
    end

    class IrcLog < Log
        @@mutex = Mutex.new
        def initialize(client)
            @client = client
            @buf = []
        end
        def out(arg)
            arg.to_s.split(/\n/).each {|a|
                @@mutex.synchronize {
                    if $gopt['showxchars']
                        @buf << a.dump
                    else
                        @buf << a
                    end
                }
            }
        end

        def o(arg)
            arg.to_s.split(/\n/).each {|a|
                @@mutex.synchronize {
                    @buf << a
                }
            }
        end

        def size()
            return @buf.length
        end
        def showbuf()
            @@mutex.synchronize do
                @buf.each {|line|
                    @client.reply line
                }
            end 
        end
        def flush()
            @@mutex.synchronize do
                @buf.clear
            end 
        end
    end
end
