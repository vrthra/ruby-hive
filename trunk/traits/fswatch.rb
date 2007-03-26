require 'basetrait'
require "filesystemwatcher"
require "yaml"

class FSWatchTrait
    include BaseTrait
    include Watch

    def init()
        @version = 0.1
        @inspect = "del list show #{@inspect}"
        @watchtable = {}
        @watchfile = 'fswatch.yaml'
        @cmdtable = {
            'create' => {}, 
            'delete'  => {},
            'modify'  => {}
        }


        @watcher = FileSystemWatcher.new()
        @watcher.sleepTime = 10
        @watcher.start { |status,file|
            sym = case status
                    when FileSystemWatcher::CREATED
                        'create'
                    when FileSystemWatcher::MODIFIED
                        'modify'
                    when FileSystemWatcher::DELETED
                        'delete' 
                    end
            p = @cmdtable[sym] || {}
            @me.set(:file,file)
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
@traits['fswatch'] = FSWatchTrait.new(self)
