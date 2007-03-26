require 'basetrait'
require 'remoteserver'
class RemoteTrait
    include BaseTrait
    def init()
        @version = 0.1
        @inspect = "start stop #{@inspect}"
        @status = "unborn"
    end
    def run(cmd, args)
        case cmd
        when /^start/i
            return start(get_first(args).to_i)
        when /^stop/i
            return stop()
        else
            return "nomatch: #{cmd} - #{args}"
        end
        return ""
    end
    def get_first(args)
        arg = args.split(/[ \t]+/)
        return arg.shift
    end

    def start(port)
        return false if !port
        begin
            DRb.start_service("druby://:#{port}", RemoteServer.new)
            @status = "started at #{DRb.uri}"
            return true
        rescue Exception => e
            @status = e.message
            return false
        end
    end

    def status
        return @status
    end

    def stop
        #DRb.thread.join
        Thread.kill(DRb.thread)
        @status = "stopped"
        return true
    end

end
@traits['remote'] = RemoteTrait.new(self)
