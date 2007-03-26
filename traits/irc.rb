#register in @me['system']
require 'basetrait'
require 'thread'
class IrcTrait
    include BaseTrait
    def init()
        @version = 0.2
        @inspect = "join part say tell #{@inspect}"
        @watchtable = {}
    end
    def run(cmd, args)
        case cmd
        when /^join/i
            args.split(/[ \t]+/).each {|chan|
                @me.join(chan)
            }
            return "#{@me.nick()}:#{@me.channels.keys.join(',')}"
        when /^part/i
            args.split(/[ \t]+/).each {|chan|
                @me.part(chan)
            }
            persist
            return "#{@me.nick()}:#{@me.channels.keys.join(',')}"
        when /^channels/i
            return "#{@me.channels.keys.join(' ')}"
        when /^say/i
            msg,channels = case args
                           when /^([^:]+):(.+)$/
                               [$1,$2]
                           else
                               [args,nil]
                           end
            return @me.say(msg,channels)
        when /^tell/i
            msg,channels = case args
                           when /^([^:]+):(.+)$/
                               [$2,$1]
                           else
                               [args,nil]
                           end
            return @me.say(msg,channels)
        else
            @me.send "#{cmd} #{args}"
            return ""
        end
        return ""
    end
end

@traits['irc'] = IrcTrait.new(self)
