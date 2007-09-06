require 'basetrait'
require 'basecron'
require 'crontab'
include CronTab
require "yaml"

class MicronTrait < BaseCronTrait
    def init()
        @version = 0.2
        @inspect = "start stop del list show #{@inspect}"
        @status = "unborn"

        @watchfile = 'micron.yaml'
        @watchtable = {}


        @tab = Crontab.new(:sec)
        start
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

    def create(name,args,cmd,expr,channel)
        time = args
        l = time.split(/ /).length
        time += " *" * (6 - l) if l < 6
        @watchtable[name] = {:channel => channel,:mask => time,:cmd => cmd, :expr => expr, :on => true}
        me = @me
        p time
        p cmd
        p name
        p channel
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
end

@traits['micron'] = MicronTrait.new(self)
