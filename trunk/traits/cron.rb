require 'basetrait'
require 'crontab'
include CronTab
require "yaml"

class CronTrait
    include BaseTrait
    include Watch
    attr_reader :status

    def init()
        @version = 0.2
        @inspect = "start stop del list show #{@inspect}"
        @status = "unborn"

        @watchfile = 'cron.yaml'
        @watchtable = {}


        @tab = Crontab.new
        start
    end

    def run(cmd, args)
        case cmd
        when /^start/i
            if args.strip.length > 0 
                return enable(args)
            else
                return start
            end
        when /^stop/i
            if args.strip.length > 0 
                return disable(args.strip)
            else
                return stop
            end
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
        @watchtable.each_key do |name|
            info = @watchtable[name]
            me = @me
            @tab.add( info[:mask],info[:cmd],info[:name],'') do
                command(me,name,info[:cmd], info[:channel]) if info[:on]
            end
        end 
    end

    def enable(args)
        @watchtable.keys.each do |c|
            if File.fnmatch(args, c) 
                cron = @watchtable[c]
                cron[:on] = true
                create c,cron[:mask],cron[:cmd],cron[:expr],cron[:channel]
            end
        end
        persist
        return true
    end

    def disable(args)
        @watchtable.keys.each do |c|
            if File.fnmatch(args, c) 
                cron = @watchtable[c]
                cron[:on] = false
                delete args,nil
            end
        end
        persist
        return true
    end

    def list(args)
        begin
            @watchtable.keys.grep(Regexp.new(args.nil? ? '.*' : args.strip)).map!{|key| "#{key}:#{@watchtable[key][:on]}"}.join(",")
        rescue Exception => e
            puts e.message
            puts e.backtrace.join("\n")
        end
    end


    def create(name,args,cmd,expr,channel)
        time = args
        l = time.split(/ /).length
        time += " * " * (6 - l) if l < 6
        @watchtable[name] = {:channel => channel,:mask => time,:cmd => cmd, :expr => expr, :on => true}
        me = @me
        @tab.add(time,cmd,name,'') do
            command(me,name,cmd,channel)
        end
        return true
    end

    def delete(args,element)
        if args.strip == '*'
            @tab.table.clear
        else
            @tab.table.delete_if {|record|
                record.nil? || record.name.nil? || record.name.strip == args
            }
        end
        return true
    end

    def start
        return false if !@thread.nil?
        @status = "started"
        @thread = Thread.new {
            while true
                @tab.run
                sleep 1
            end
        }
        return true
    end

    def stop
        Thread.kill(@thread) if @thread
        @thread = nil
        @status = "stopped"
        return true
    end

end
@traits['cron'] = CronTrait.new(self)
