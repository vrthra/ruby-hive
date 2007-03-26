require 'basetrait'
require 'patlog'
require 'patscript'

include Pat

class PatTrait
    include BaseTrait
    def init()
        @version = 0.1
        @inspect = "start atfinish #{@inspect}"
        @status = "unborn"
    end
    def run(cmd, args)
        case cmd
        when /^start/i
            return start(args)
        when /^atfinsh/i
            #allow an me to be executed
        when /^flush/i
            return flush()
        when /^show/i
            return show()
        when /^size/i
            return size()
        else
            return "nomatch: #{cmd} - #{args}"
        end
        return ""
    end

    def start(args)
        begin
            @store = PatStore.new(Patlog::IrcLog.new(self))
            #parse args and find the things.
            @store.parse_opt(args.split(/ +/))
            s = Pat::Seq.new @store
            @status = "failed:#{$failed}"
            return @status
        rescue SystemExit => e
            puts "restarting..?"
            return "restarting.. #{e.message}"
        rescue Exception => e
            @status = e.message
            puts "pat>#{e.message}"
            puts e.backtrace.join("\n")
            return "exception .. #{e.message}"
        end
    end
    def size
        return @store.log.size
    end
    def show
        @store.log.showbuf
        return true
    end
    def flush
        @store.log.flush
        return true
    end

    def status
        return @status
    end
end

@traits['pat'] = PatTrait.new(self)

