#register in @me['system']
require 'basetrait'
require 'pathname'
class FileTrait
    include BaseTrait
    def init()
        @version = 0.2
        @inspect = "exist rm #{@inspect}"
    end
    def run(cmd, args)
        case cmd
        when /^exist/i
            return Pathname.new(get_first(args)).exist?.to_s
        when /^rm/i
            return Pathname.new(get_first(args)).unlink().to_s
        else
            return "nomatch: #{cmd} - #{args}"
        end
        return ""
    end
    def get_first(args)
        arg = args.split(/[ \t]+/)
        return arg.shift
    end
end
@traits['file'] = FileTrait.new(self)
