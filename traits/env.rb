require 'basetrait'
class EnvTrait
    include BaseTrait
    def init()
        @version = 0.1
    end
    def run(cmd, args)
        case args
        when /^[ ]*$/
            res = "#{ENV[cmd]}"
            return res
        else
            return ENV[cmd] = args.strip
        end
    end
end
@traits['env'] = EnvTrait.new(self)
