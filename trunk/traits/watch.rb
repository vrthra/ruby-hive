require 'basetrait'
require "yaml"

class WatchTrait
    include BaseTrait
    include Watch

    def init()
        @version = 0.1
        @inspect = "del list show #{@inspect}"
        @watchtable = {}
        @watchfile = 'watch.yaml'
        @cmdtable = {
            'privmsg' => {}, 
            'notice'  => {},
            'join'  => {},
            'part'  => {},
            'quit'  => {}
        }
        @me.on(:privmsg) do |user, channel, msg|
            on_event('privmsg',user,channel,msg)
        end
        @me.on(:notice) do |user, channel, msg|
            on_event('notice',user,channel,msg)
        end
        @me.on(:join) do |user, channel|
            on_event('join',user,channel,nil)
        end
        @me.on(:part) do |user, channel, msg|
            on_event('part',user,channel,msg)
        end
        @me.on(:quit) do |user, msg|
            on_event('quit',user,nil,msg)
        end
    end

    def on_event(event,user,channel,msg)
        p = @cmdtable[event] || {}
        @me.set(:user,user)
        @me.set(:msg,msg)
        @me.set(:channel,channel)
        p.keys.each {|key|
            w = @watchtable[key][:mask]
            p[key][channel].call if p[key][channel] && msg + ':' + user =~ /#{w}/
        }
    end

    def run(cmd, args)
        case cmd
        when /^del/i
            return del(args)
        when /^list/i
            return list(args)
        when /^show/i
            return show(args)
        else
            return at(cmd,args)
        end
        return ""
    end

    def restore
        super
        @watchtable.each_key {|name|
            me = @me
            event = @watchtable[name][:event]
            cmd = @watchtable[name][:cmd]
            channel = @watchtable[name][:channel]
            @cmdtable[event][name] = {channel => Proc.new { command(me,name,cmd,channel) } }
        }
    end

    def create(name,args,cmd,expr,channel)
        if args =~ /^([^:]+):(.*)$/
            event,mask = $1,$2
            @watchtable[name] = {:channel => channel,:event => event,:mask => mask,:cmd => cmd, :expr => expr}

            if @cmdtable[event]
                me = @me
                @cmdtable[event][name] = { channel => Proc.new { command(me,name,cmd,channel) } }
                return true
            else
                return false
            end
        else
            return false
        end
    end

    def delete(args,element)
        if args.strip == '*'
            @cmdtable.clear
        else
            @cmdtable.keys.each {|event| @cmdtable[event].delete(args) }
        end
        return true
    end
end
@traits['watch'] = WatchTrait.new(self)
