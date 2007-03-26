#register in @me['system']
require 'basetrait'
require 'pathname'
class RubyTrait
    include BaseTrait
    def init()
        @version = 0.2
        @inspect = "eval #{@inspect}"
    end
    def run(cmd, args)
        case cmd
        when /^eval/i
            return eval(args)
        else
            return eval("#{cmd} #{args}")
        end
        return ""
    end
end
@traits['ruby'] = RubyTrait.new(self)
