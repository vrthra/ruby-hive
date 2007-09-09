module BaseTrait
    def initialize(me)
        @me = me
        @version = 0.1
        @inspect = " inspect version echo trace status help"
        @status = "ready"
        @store = {}
        @last_res = {}
        @basedir = @me.session[:basedir] || ''

        init
        #load any saved data
        restore
    end

    def init
    end

    def help
        usage <<EOU
Trait #{self.to_s}
not - impl
EOU
    end

    def persist
    end

    def restore
    end

        
    def lines(str)
        case str.class.to_s
        when /Array/
            str.each {|line|
                @me.say line.chomp, @me.session[:channel]
            }
        when /String/
            str.split(/\n/).each {|line|
                @me.say line.chomp, @me.session[:channel]
            }
        else
            @me.say str, @me.session[:channel]
        end
        ''
    end
    
    alias usage lines 
    
    class TraitProxy
        def initialize(obj)
            @obj=obj
        end
        def method_missing(meth, *args, &block)
            @obj.send(meth, *args, &block)
        end
        def =~(o)
            return @obj =~ o
        end
        def ==(o)
            return @obj == o
        end
        def ===(o)
            return @obj === o
        end
        def to_s
            case @obj.class.to_s
            when /String/
                return @obj.chomp.strip.gsub(/\n/,'|')
            when /Hash/
                return @obj.keys.join(' ')
            when /Array/
                return @obj.join(' ')
            else
                return @obj.to_s
            end
        end
    end

    def invoke(id,cmd, args)
        @_id = id.to_s
        @_cmd = cmd
        @_args = args
        args = "" if args.nil?
        
        case cmd
        when /^inspect/i
            if args =~ /^$/
                return @inspect
            else
                return inspect(args)
            end
        when /^version/i
            return version(args)
        when /^echo/i
            return args
        when /^trace/i
            return "#{cmd}:#{args}"
        when /^status/i
            return status()
        when /^help/i
            return help()
        else
            res = run(cmd,args)
            r = TraitProxy.new(res)
            @last_res[@_id] = r
            return nil if res.nil?
            return r
        end
        return nil
    end

    def store(args)
        if args.nil? || args.length == 0
            @store[@_id] = nil
            @me.more(0)
            return
        end
        @store[@_id] = args
        @me.more(args.length)
    end

    def get_store()
        return @store
    end

    def next(id,cmd=nil,args=nil)
        val = @store[id.to_s]
        if !val.nil? && val.length > 0
            res = @store[id.to_s].shift
            @last_res[id.to_s] = res
            @me.more(@store[id.to_s].length)
            return res.chomp.gsub(/\n/,'|')
        else
            @store[id.to_s] = nil
            @me.more(0)
            return "#{@last_res[id.to_s]}".chomp.gsub(/\n/,'|')
        end
    end

    def version(args)
        return @version
    end

    def status()
        return @ready
    end

    def inspect(args)
        return "not impl"
    end

    def run(cmd,args)
        return "not impl:#{cmd}:#{args}"
    end

    def reply(str)
        @me.reply str
    end

    def to_s
        c = self.class.to_s[/[^:]+$/].downcase[0...-5]
        return c + ':' + @version.to_s
    end
end

module Watch
    def command(me, name,cmd,chan)
        #exception is caught at command
        Thread.new {
		me.say me.command(cmd,chan),chan
        }
    end

    def restore
        @watchtable = (File.open(@basedir + '/' + @watchfile){|y| YAML::load(y)} if FileTest.exists?(@basedir + '/' + @watchfile)) || {}
    end

    def persist
        File.open(@basedir + '/' + @watchfile,"w") {|f|
            f.puts @watchtable.to_yaml
        }
    end

    #$watch.list()
    def list(args)
        begin
        @watchtable.keys.grep(Regexp.new(args.nil? ? '.*' : args.strip)).join(",")
        rescue Exception => e
            puts e.message
            puts e.backtrace.join("\n")
        end
    end

    #$watch.show("mexico")
    def show(args)
        channel = @me.get(:channel)
        @watchtable[channel + ':' + args.strip][:expr] if @watchtable.include?(channel + ':' + args.strip)
    end


    #$watch.del("mexico")
    def del(args)
        return false if args.nil?
        channel = @me.get(:channel)
        if args.strip == '*'
            @watchtable.clear
            return false if !delete(args.strip,nil)
        else
            element = @watchtable.delete(channel + ':' + args.strip)
            return false if element.nil? || !delete(channel + ':' + args.strip,element)
        end
        persist
        return true
    end

    #on(name,join:.*)
    def at(name,args)
        return false if !name || name.empty? || !args || args.empty?
        cmd = @me.session[:do]
        expr = @me.session[:expr]
        channel = @me.get(:channel)
        del(name)
        return false if !create(channel + ':' + name, args, cmd, expr, channel)
        persist
        return true
    end
end
