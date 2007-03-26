require 'basetrait'
require "mailwatcher"
require "yaml"

class MailWatchTrait
    include BaseTrait
    include Watch

    def init()
        @version = 0.1
        @inspect = "del list show #{@inspect}"
        @watchtable = {}
        @watchfile = 'mailwatch.yaml'
        @cmdtable = {
            'match'  => {},
            'nomatch'  => {},
            'exception'  => {}
        }

        @watcher = MailWatcher.new { |status,mail|
            sym = case status
                    when MailWatcher::MATCH
                        'match'
                    when MailWatcher::NOMATCH
                        'nomatch'
                    when MailWatcher::EXCEPTION
                        'exception'
                    end
            p = @cmdtable[sym] || {}
            @me.set(:mail,mail)
            @me.set(:mailheaders,mail[:headers])
            @me.set(:mailbody,mail[:body])
            @me.set(:mailfrom,mail[:headers][:From])
            @me.set(:mailto,mail[:headers][:To])
            @me.set(:mailsubject,mail[:headers][:Subject])
            p.keys.each {|key|
                p[key].call
            }
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
    end

    def restore
        super
        @watchtable.each_key {|name|
            me = @me
            event = @watchtable[name][:event]
            cmd = @watchtable[name][:cmd]
            channel = @watchtable[name][:channel]
            mask = @watchtable[name][:mask]
            @cmdtable[event][name] = Proc.new { command(me,name,cmd,channel) }
            @watcher.add(name,mask)
        }
    end

    def create(name,args,cmd,expr,channel)
        event,mask = 'match',args
        if args =~ /([^:]+):(.+)$/
            event = $1
            mask = $2
        end

        @watchtable[name] = {:channel => channel,:event => event,:mask => mask,:cmd => cmd, :expr => expr}

        if @cmdtable[event]
            me = @me
            @cmdtable[event][name] = Proc.new { command(me,name,cmd,channel) }
            @watcher.add(name,mask)
            return true
        else
            puts "returning false...."
            return false
        end
    end

    def delete(args,element)
        if args == '*'
            @watcher.clear
            @cmdtable.clear
        else
            @watcher.remove(args.strip)
            @cmdtable.keys.each {|event| @cmdtable[event].delete(args) }
        end
    end

end
@traits['mailwatch'] = MailWatchTrait.new(self)
