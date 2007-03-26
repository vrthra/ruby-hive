require 'basetrait'
require 'timeout'
class SystemTrait
    include BaseTrait
    def init()
        @version = 0.3
        @inspect = "os hostname tag sync restart reload exec #{@inspect}"
        @timeout = 10
    end
    def run(cmd, args)
        case cmd
        when /^platform/i
            return RUBY_PLATFORM
        when /^os/i
            return `uname -s`.chomp + "-" + `uname -p`.chomp
        when /^host/i
            hostname = Socket.gethostname.split(/\./).shift
            return hostname
        when /^tag/i
            @tag = args.strip if args.strip().length > 0
            return @tag
        when /^traits/i
            #return Dir["traits/*.rb"].join(" ")
            return $traits.keys.join(" ")
        when /^sync/i
            arg = 'all'
            if args.strip().length > 0
                arg = args
            end
            return "#{@me.sync(arg)}"
        when /^restart/i
            exit 0
            return "true"
        when /^reload/i
            agt = args.strip
            $traits[agt] = nil
            puts "reload[#{args}]"
            return "true"
        when /^cd$/i
            Dir.chdir(args.strip)
            return Dir.pwd
        when /^timeout/i
            @timeout = args.strip.to_i
            return "#{@timeout}"
        else #defult is to exec it
            @out = get_output(cmd + " " + args)
            return false if @out.nil?
            case @out.length
            when 1
                return @out.shift
            when 0
                return ""
            else
                res = @out.shift
                store(@out)
                return res.chomp
            end
        end
    end
    def status(args)
        if args =~ /system/
            return @me.status()
        else
            return @status
        end
    end
    def get_output(cmdstr)
        puts "executing: #{cmdstr}"
        f = nil
        arr = [] 
        begin
            Timeout.timeout(@timeout) {
                f = IO.popen("#{cmdstr}")
                arr = f.readlines
            }
            return arr
        rescue Timeout::Error
            puts "timed out:#{@timeout}"
            return nil
        ensure
            puts "closing #{cmdstr}"
            f.close if !f.nil?
        end
    end

end
@traits['system'] = SystemTrait.new(self)
