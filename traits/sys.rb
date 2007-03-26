require 'basetrait'
require 'timeout'
class SysTrait
    include BaseTrait
    def init()
        @version = 0.3
        @inspect = "os hostname tag sync restart reload exec #{@inspect}"
        @timeout = 10
    end
    def run(cmd, args)
        case cmd
        when /^timeout/i
            @timeout = args.strip.to_i
            return "#{@timeout}"
        when /^cd$/i
            Dir.chdir(args.strip)
            return Dir.pwd
        else #defult is to exec it
            @out = get_output(cmd + " " + args)
            return false if @out.nil?
            return @out
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
                arr = f.readlines.collect{|l|l.chomp}
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
@traits['sys'] = SysTrait.new(self)
