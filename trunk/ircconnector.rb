require 'netutils'
require 'ircreplies'
require 'actors'

module HiveConnector
    class IrcConnector
        include IRCReplies
        include NetUtils
        extend NetUtils

        attr_reader :server, :port, :nick, :socket
        attr_writer :actor, :socket
        def initialize(server, port, nick, pass)
            @server = server
            @port = port
            @nick = nick
            @pass = pass
            @actor = Actors::HiveActor.new(self)
            @readlock = Mutex.new
            @writelock = Mutex.new


            @inputlock = Mutex.new
            @inputqueue = ConditionVariable.new
        end

        def run
            connect()
            @eventloop = Thread.new { @actor.run }
            listen_loop
        end

        def connect()
            begin
                #allow socket to be handed over from elsewhere.
                @socket = @socket || TCPSocket.open(@server, @port)
                @actor[:connect].each{|c| c[ @server, @port, @nick, @pass]}
            rescue
                raise "Cannot connect #{@server}:#{@port}"
            end
        end
       
        #=========================================================== 
        def process(input)
            input.untaint
            s = input
            prefix = ''
            user = ''
            if input =~ /^:([^ ]+) +(.*)$/
                s = $2
                prefix = $1
                user = if prefix =~ /^([^!]+)!(.+)/
                           $1
                       else
                           prefix
                       end
            end

            cmd = s
            suffix = ''
            if s =~ /([^:]+):(.*)$/
                cmd = $1.strip
                suffix = $2
            end
            case cmd
            when /^PING$/i
                #dont bother about event loop here.
                @actor[:ping][suffix]
            when /^PONG$/i
                @actor[:pong][suffix]
            when /^NOTICE +(.+)$/i
                @actor.push :notice, user, $1, suffix
            when /^PRIVMSG +(.+)$/i
                @actor.push :privmsg, user, $1, suffix
            when /^JOIN$/i
                #the confirmation join channel will come in suffix
                @actor.push :join, user, suffix
            when /^PART +(.+)$/i
                #the confirmation part channel will come in cmd arg.
                @actor.push :part, user, $1, suffix
            when /^QUIT$/i
                @actor.push :quit, user, suffix
            when /^([0-9]+) +(.+)$/i
                server,numeric,msg,detail = prefix, $1.to_i,$2, suffix
                @actor.push :numeric, server,numeric,msg,detail if !local_numeric(numeric,msg,detail)
            else
                @actor.push :unknown, input
            end
        end

        def listen_loop()
            process(gets) while !@socket.eof?
        end

        #WARNING: UGLY HACK. 
        def local_numeric(numeric,msg,detail)
            if @capture_numeric
                case numeric
                when ERR_NOSUCHNICK
                    if msg =~ / *[^ ]+ +([^ ]+)*$/
                        if $1 == @capture_channel
                            @inputlock.synchronize {
                                @args << [numeric,msg,detail]
                                @inputqueue.signal
                            }
                            return true
                        end
                    end
                when RPL_ENDOFNAMES
                    if msg =~ / *[^ ]+ +([^ ]+)*$/
                        if $1 == @capture_channel
                            @inputlock.synchronize {
                                @args << [numeric,msg,detail]
                                @inputqueue.signal
                            }
                            return true
                        end
                    end
                when RPL_NAMREPLY
                    if msg =~ / *[^ ]+ *= +([^ ]+)*$/
                        if $1 == @capture_channel
                            @inputlock.synchronize {
                                @args << [numeric,msg,detail]
                                @inputqueue.signal
                            }
                            return true
                        end
                    end
                end
            end
            return false #continue with processing
        end

        #will be invoked from a thread different from that of the
        #primary IrcConnector thread.
        def names(channel)
            carp "invoke names for #{channel}"
            @names = []
            @args = []
            @capture_channel = channel.chomp
            @capture_numeric = true
            send_names channel
            while true
                numeric, msg, detail = 0,'',''
                @inputlock.synchronize {
                    @inputqueue.wait(@inputlock) if @args.empty?
                    numeric, msg, detail = @args.shift
                }
                case numeric
                when ERR_NOSUCHNICK
                    carp ERR_NOSUCHNICK
                    break
                when RPL_ENDOFNAMES
                    carp "#{RPL_ENDOFNAMES} #{@names}"
                    break
                when RPL_NAMREPLY
                    nicks = detail.split(/ +/)
                    nicks.each {|n| @names << $1.strip if n =~ /^@?([^ ]+)/ }
                    carp "nicks #{nicks}"
                end
            end
            carp "returning #{@names}"
            @capture_numeric = false
            return @names
        end

        #=====================================================
        def lock_read
            @readlock.lock
        end
        def unlock_read
            @readlock.unlock
        end
        def lock_write
            @writelock.lock
        end
        def unlock_write
            @writelock.unlock
        end
        #=====================================================
        def send_pong(arg)
            send "PONG :#{arg}"
        end
        def send_pass(pass)
            send "PASS #{pass}"
        end
        def send_nick(nick)
            send "NICK #{nick}"
        end
        def send_user(user,mode,unused,real)
            send "USER #{user} #{mode} #{unused} :#{real}"
        end
        def send_names(channel)
            send "NAMES #{channel}"
        end
        def send(msg)
            send "#{msg}"
        end
        #=====================================================
        def send_join(channel)
            send "JOIN #{channel}"
        end
        def send_part(channel)
            send "PART #{channel} :"
        end

        def msg_user(user,data)
            msg_channel(user, data)
        end

        def msg_channel(channel, data)
            send "PRIVMSG #{channel} :#{data}"
        end
        
        def notice_channel(channel, data)
            send "NOTICE #{channel} :#{data}"
        end

        def gets
            s = nil
            @readlock.synchronize { 
                s = @socket.gets
            }
            #carp "<#{s}"
            return s 
        end
        
        def send(s)
            carp ">#{s}"
            @writelock.synchronize { @socket << "#{s}\n" }
        end
        #=====================================================
        def IrcConnector.start(opts={})
            server = opts[:server] or raise 'No server defined.'
            nick = opts[:nick] || '_' + Socket.gethostname.split(/\./).shift
            port = opts[:port] || 6667
            pass = opts[:pass] || 'netserver'
            client = IrcConnector.new(server, port , nick, pass)
            #client.actor = PrintActor.new(client)
            client.actor = TestActor.new(client)
            begin
                client.run
            rescue SystemExit => e
                puts "exiting..#{e.message()}"
                exit 0
            rescue Interrupt
                exit 0
            rescue Exception => e
                carp e
            end
        end
    end
    CONNECTOR = IrcConnector
#=====================================================
    if __FILE__ == $0
        server = 'localhost'
        port = 6667
        nick = 'genericclient'
        while arg = ARGV.shift
            case arg
            when /-s/
                server = ARGV.shift
            when /-p/
                port = ARGV.shift
            when /-n/
                nick = ARGV.shift
            when /-v/
                $verbose = true
            end
        end
        IrcConnector.start :server => server, 
            :port => port, 
            :nick => nick, 
            :pass => 'netserver'
    end
end
