module Agent
    require 'timeout'
    require "socket"
    require "yaml"
    require "strscan"
    require 'actors'
    require 'netutils'

    #===========remote actor==============================
    require 'cmdscanner'
    include Scanner

    class TraitStore
        include NetUtils
        def initialize(me)
            @me = me
            @traitfile= 'traits.yaml'
            @store = {}
        end

        def init
            names = restore(@traitfile)
            names.each {|name|
                carp "loaded trait #{name}" if load_trait(name)
            }
        end

        def names
            return @store.keys
        end

        def [](trait)
            return @store[trait] || load_trait(trait)
        end

        def []=(trait,instance)
            @store[trait] = instance
        end
        
        def persist(file,map)
            File.open(file,"w") {|f|
                f.puts map.to_yaml
            }
        end

        def restore(file)
            (File.open(file){|f| YAML::load(f)} if FileTest.exists?(file)) || {}
        end


        #populate the @store[:name] with a new instance
        def load_trait(trait)
            begin
                return nil if trait.nil? || trait.chomp.length.zero?
                @me.instance_eval(get_resource('traits/' + trait),trait + '.rb',0) 
                persist @traitfile, @store.keys
                return @store[trait]
            rescue Exception => e
                #carp e
                raise "#{trait} [#{e.message}]"
            end
        end
    end

    class SeqFile
        attr_reader :result
        def initialize(arr,fn='compile')
            @result = arr.collect {|line|
                case line
                when /^ *\[ *$/
                    "#{fn} '',{}, <<EOF"
                when /^ *\[ *([^\]]+)$/
                    "#{fn} '',{#{$1}}, <<EOF"
                when /^ *\] *$/
                    "EOF"
                else
                    line
                end
            }
        end
    end

    class RemoteActor < Actors::HiveActor
        alias join_channel join
        alias part_channel part
        attr_reader :tag,:map,:group,:threads
        attr_writer :tag,:map,:group
        @@id = 0
        def initialize(client, channel=nil)
            super(client)
            channel ||= $config['hive']
            @channel = channel
            @has_more = 0
            @result_store = {}
            @channelfile = 'channels.yaml'
            @map = {}
            @group = []
            @tag = 'bee'
            @threads = {}
            @osession = {
                :basedir => Dir::pwd,
                :host => Socket.gethostname.split(/\./).shift,
                :os => RUBY_PLATFORM
            }
            @session = @osession.dup

            #this needs to be done after all other initializations have happened.
            @traits = TraitStore.new(self)
            @traits.init

            on(:connect) do |server, port, nick, pass|
                @port = port
                @nick = nick
                begin
                @channels = restore(@channelfile)
                @channels[channel] = Time.now
                
                @channels.each_key {|c|
                    join c
                }
                persist @channelfile,@channels
                rescue Exception => e
                    puts e.message
                    puts e.backtrace.join("\n")
                end
            end

            on(:privmsg) do |user, channel, msg|
                processmsg(user, channel, msg)
            end
        end

        def reload(trait)
            @traits.load_trait trait
        end

        def loaded_traits
            @traits.names
        end

        def processmsg(user, channel, msg)
            return if msg !~ /^!/
            case msg
            when /^!(select|insert|delete|create|drop|update|triggers|sequence)\b/
                #ignore.
            when /^!(where +.+)$/i
                handle_expr($1, '=', channel, user)
            when /^!(do +.+)$/i
                handle_expr($1, '=', channel, user)
            when /^!(when +.+)$/i
                handle_expr($1, '=', channel, user)
            when /^!more *$/i
                handle_nextcmd('=', channel, user)
            when /^!\$([0-9a-zA-Z_-]+\:[0-9a-zA-Z_-]+) *$/i
                handle_cmd($1, '','=', channel, user)
            when /^!\$([0-9a-zA-Z_-]+\:[0-9a-zA-Z_-]+) *(.*)$/i
                handle_cmd($1, $2,'=', channel, user)
            when /^!\$([0-9a-zA-Z_-]+) *(.*)$/i
                handle_cmd($1, $2,'=', channel, user)
            when /^!(.*)/
                handle_eval($1,channel,user)
            end
        end
        
        def persist(file,map)
            File.open(file,"w") {|f|
                f.puts map.to_yaml
            }
        end

        def restore(file)
            (File.open(file){|y| YAML::load(y)}if FileTest.exists?(file)) || {}
        end

        def join(channel)
            channel.split(/,/).each {|c|
                join_channel c.strip
            }
            persist @channelfile,@channels
        end

        def part(channel)
            return 'default' if channel =~ Regexp.new($config['hive'])
            if channel.strip.length == 0
                part_channel session[:channel]
            else
                channel.split(/,/).each {|c|
                    part_channel c.strip
                }
            end
            persist @channelfile,@channels
        end

        #we have to tell this to ourselves too.
        def say(msg,rc=nil)
            rc ||= get_target(session[:channel],session[:user])
            rc.split(/,/).each {|c|
                send_message c.strip,msg
                if channels.keys.include?(c.strip) || c.strip == nick
                    processmsg nick, c.strip, msg
                    @traits['watch'].on_event('privmsg',nick, c.strip, msg)
                end
            }
            "=>#{rc}"
        end
        
        def handle_eval(expr,channel,user)
            rc = get_target(channel,user)
            begin
                #we dont want to dup here as this is a way to directly
                #modify the program behavior
                me = self
                me.session = @osession.dup
                me.session[:channel] = channel
                me.session[:user] = user
                say me.instance_eval(expr,':expr',0),rc
            rescue SystemExit => e
                exit 0
            rescue Exception => e
                say e.message,rc
                carp e
            end
        end

        def restart
            exit 0
        end

        def version
            $config['version']
        end

        def handle_cmd(cmd, arg, ret, channel, user)
            @session = @osession.dup
            session[:channel] = channel
            session[:user] = user
            rc = get_target(channel,user)
            #strip paren in case they are used.
            args = case arg
                   when /^\[(.*)\] *$/
                       $1
                   else
                       arg
                   end
            case cmd
            when /^([a-zA-Z0-9_-]+)\:([a-zA-Z0-9_-]+) *$/
                id = @@id
                @@id += 1
                t = Thread.new {
                    begin
                        @threads[id] = Thread.current
                        Thread.current[:expr] = cmd
                        Thread.current[:time] = Time.now
                        res = @traits[$1].invoke(0,$2, args)
                        say "#{ret}#{res}",rc
                        while @has_more > 0
                            @has_more = 0
                            nxt = @traits[$1].next('0')
                            say "#{ret}#{nxt}",rc
                        end
                    rescue SystemExit => e
                        exit 0
                    rescue Exception => e
                        #say "#{ret} error:#{e.message}",rc
                        #dont say anything on this kind of error.
                    ensure
                        @threads.delete(id)
                    end
                }
            when /^seq/
                seq args.strip
            when /^join/
                join args.strip
            when /^part/
                part args.strip
            end
        end

        def command(cmd, channel)
            begin
                return do_cmd(cmd, "", channel)
            rescue SystemExit => e
                exit 0
            rescue Exception => e
                carp e
                return "error(#{@nick}):#{e.message}"
            end
        end

        def use(dummy,hash,str)
            oldsess = @session.dup
            hash.keys.each {|key|
            @session[key] = hash[key]
            }
            str.split("\n").each {|line|
                line.chomp!
                processmsg session[:user], session[:channel], line if channels.include?(session[:channel])
            }
            @session = oldsess
        end

        def seq(file)
            begin
                seq = get_resource(file,'.seq')
                arr = seq.split("\n").collect{|line|line.chomp}
                s = SeqFile.new(arr,'use')
                src = s.result.join("\n")
                self.instance_eval src
            rescue Exception => e
                say e.message, channel()
                carp e
            end
        end

        def get_target(channel,user)
            if channel =~ /^#.*/
                return channel
            else
                return user
            end
        end
        #!where #{where} do groupby|:|selectexpr
        def handle_expr(cmd, ret, channel, user)
                id = @@id
                @@id += 1
                t = Thread.new {
                    begin
                        @threads[id] = Thread.current
                        Thread.current[:expr] = cmd
                        Thread.current[:time] = Time.now


                        rc = get_target(channel,user)
                        @session = @osession.dup
                        @session[:channel] = rc
                        say do_cmd(cmd, ret, rc),rc
                    rescue SystemExit => e
                        exit 0
                    rescue Exception => e
                        say "#{ret} error(#{@nick}):#{e.message}",rc
                        carp e
                    ensure
                        @threads.delete(id)
                    end
                }
        end

        def handle_nextcmd(ret, channel, user)
            rc = get_target(channel,user)
            expr = @result_store[rc.strip]
            c = CmdScanner.new(expr)
            obj = CmdStich.new(c.result,'next')
            begin
                res =  self.instance_eval(obj.dostr, ':next',0)
                str = if @has_more > 0 
                          "#{ret}#{@has_more.to_s}:#{res}"
                      else
                          "#{ret} #{res}"
                      end
                @has_more = 0
                say str,rc
            rescue SystemExit => e
                exit 0
            rescue Exception => e
                say "#{ret} error(#{@nick}):#{e.message}",rc
                carp e
            end
        end

        def channel
            return @session[:channel] || $config['hive']
        end
        
        def set(arg,val)
            return @session[arg] = val
        end

        def get(arg)
            return @session[arg]
        end

        def session=(arg)
            @session = arg
        end

        def session()
            @session
        end

        def traits=(arg)
            @traits = arg
        end

        def do_cmd(expr,ret,channel)
            c = CmdScanner.new(expr)
            obj = CmdStich.new(c.result,'invoke')
            me = self
            me.session[:expr] = expr
            if obj.whenstr.length > 0
                    str = StrStich.new(c.result)
                    me.session[:do] = "!do " + str.dostr + 
                        (str.wherestr.length > 0 ? " where " + str.wherestr : '')
                    res =  me.instance_eval(obj.whenstr, ':when',0)
                    return "#{ret} #{res}"
            elsif me.instance_eval(obj.wherestr, ':where',0)
                @has_more = 0
                res = nil
                if obj.whenstr.length > 0
                    #get naked dostr
                    str = StrStich.new(c.result)
                    me.session[:do] = "!do " + str.dostr + 
                        (str.wherestr.length > 0 ? " where " + str.wherestr : '')
                    res =  me.instance_eval(obj.whenstr, ':when',0)
                else
                    res =  me.instance_eval(obj.dostr, ':do',0)
                end
                if @has_more > 0 
                    res = "#{ret}#{@has_more.to_s}:#{res}"
                else
                    res = "#{ret} #{res}"
                end

                #save the previous query incase a next is asked (even if we dont have a next)
                @result_store[channel] = expr
                @has_more = 0
                return res
            else
                return ret
            end
        end

        def interpret_query(expr, cmd)
            c = CmdScanner.new(expr)
            obj = CmdStich.new(c.result,cmd)
            return obj
        end
        #=====================================================
        def more(val=nil)
            return @has_more if val.nil?
            if val > @has_more
                @has_more = val
            end
        end
    end

    #=====================================================

    # The irc class, which talks to the server and holds the main event loop
    def include(arg)
        Object.module_eval "include #{arg}"
    end
    #=====================================================
    class RemoteClient
        include NetUtils
        extend NetUtils
        def RemoteClient.start(home=nil, port=nil)
            home ||=$config['home']
            port ||=$config['port']
            hostname = Socket.gethostname.split(/\./).shift
            require $config['connector']
            rc = HiveConnector::CONNECTOR.new(home, port, '_' + hostname, 'hive')
            rc.actor = RemoteActor.new(rc)
            begin
                rc.run
            rescue SystemExit
                return
            rescue Interrupt
                return
            rescue Exception => e
                carp e
                return
            end
        end
        #=====================================================
    end
end
