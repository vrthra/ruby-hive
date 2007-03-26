require 'basetrait'
require "urlwatcher"
require "yaml"

class UrlWatchTrait
    include BaseTrait
    include Watch

    def init()
        @version = 0.1
        @inspect = "del list show #{@inspect}"
        @watchtable = {}
        @watchfile = 'urlwatch.yaml'
        @cmdtable = {
            'create' => {}, 
            'delete'  => {}
        }


        @watcher = UrlWatcher.new()
        @watcher.sleepTime = 10
        @watcher.start { |status,url|
            sym = case status
                    when UrlWatcher::CREATED
                        'create'
                    when UrlWatcher::DELETED
                        'delete' 
                    end
            p = @cmdtable[sym] || {}
            @me.set(:url,url)
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
        return ""
    end

    def restore
        super
        @watchtable.each_key {|name|
            me = @me
            event = @watchtable[name][:event]
            cmd = @watchtable[name][:cmd]
            channel = @watchtable[name][:channel]
            @cmdtable[event][name] = Proc.new { command(me,name,cmd,channel) }
        }
    end

    def create(name,args,cmd,expr,channel)
        event,mask = case args 
                     when /^([^:]+):(.+)/ 
                         [$1,$2] 
                     end
        @watchtable[name] = {:channel => channel,:event => event,:mask => mask,:cmd => cmd, :expr => expr}

        if @cmdtable[event]
            me = @me
            @cmdtable[event][name] = Proc.new { command(me,name,cmd,channel) }
            @watcher.add(mask)
            return true
        else
            return false
        end
    end

    def delete(args,element)
        if args == '*'
            @watcher.clear
            @cmdtable.clear
        else
            @watcher.remove(element[:mask])
            @cmdtable.keys.each {|event| @cmdtable[event].delete(args) }
        end
    end

end
@traits['urlwatch'] = UrlWatchTrait.new(self)
