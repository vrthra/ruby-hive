require 'crontab'
include CronTab
require "yaml"

class BaseCronTrait
    include BaseTrait
    include Watch
    attr_reader :status

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

end


