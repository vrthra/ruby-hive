module Actors
    require 'timeout'
    require "socket"
    require 'thread'
    require 'ircreplies'
    require 'netutils'

    include IRCReplies

    # The irc class, which talks to the server and holds the main event loop
    class HiveActor
        include NetUtils
        attr_reader :channels
        #=========================================================== 
        #events
        #=========================================================== 
        def initialize(client)
            @client = client
            @eventqueue = ConditionVariable.new
            @eventlock = Mutex.new
            @events = []
            @channels = {}
            @store = {
                :ping => 
                Proc.new {|server|
                    client.send_pong server
                },
                :pong => 
                Proc.new {|server|
                    puts "pong:#{server}"
                },
                :notice=>
                [Proc.new {|user,channel,msg|
                    puts "Server:#{msg}"
                    #client.msg_channel channel,"message from #{user} on #{channel} : #{msg}"
                }],
                :privmsg =>
                [Proc.new {|user,channel,msg|
                    #puts "message from #{user} on #{channel} : #{msg}"
                    #client.msg_channel channel,"message from #{user} on #{channel} : #{msg}"
                }],
                :connect =>
                [Proc.new {|server,port,nick,pass|
                    #puts "on connect #{server}:#{port}"
                    client.send_pass pass
                    client.send_nick nick
                    client.send_user nick,'0','*',"#{server} Net Bot"
                }],
                :numeric =>
                [Proc.new {|server,numeric,msg,detail|
                    #puts "on numeric #{server}:#{numeric}"
                }],
                :join=>
                [Proc.new {|nick,channel|
                    #puts "on join"
                }],
                :part=>
                [Proc.new {|nick,channel,msg|
                    #puts "on part"
                }],
                :quit=>
                [Proc.new {|nick,msg|
                    #puts "on quit"
                }],
                :unknown =>
                [Proc.new {|line|
                    puts ">unknown message #{line}"
                }]
            }
        end
        
        #=========================================================== 
        #on_xxx appends to registered callbacks
        #use [] to reset callbacks
        #=========================================================== 
        def on_connect(&block)
            raise IrcError.new('wrong arity') if block.arity != 4
            self[:connect] << block
        end
        def on_ping(&block)
            raise IrcError.new('wrong arity') if block.arity != 1
            self[:ping] << block
        end
        def on_privmsg(&block)
            raise IrcError.new('wrong arity') if block.arity != 3
            self[:privmsg] << block
        end
        def on_numeric(numarray,&block)
            raise IrcError.new('wrong arity') if block.arity != 4
            self[:numeric] << Proc.new {|server,numeric,msg,detail|
                case numeric
                when *numarray
                    block.call(server,numeric,msg,detail)
                end
            }
        end
        def on_rpl(num,&block)
            raise IrcError.new('wrong arity') if block.arity != 3
            self[:numeric] << Proc.new {|server,numeric,msg,detail|
                block.call(server,msg,detail) if num == numeric
            }
        end
        def on_err(num,&block)
            on_rpl(num,block)
        end
        def on(method,&block)
            self[method] << block
        end
        #=========================================================== 
        def [](method)
            @store[method] = [] if @store[method].nil?
            return @store[method]
        end

        def push(method,*args)
            @eventlock.synchronize {
                @events << [method,args]
                @eventqueue.signal
            }
        end
        
        def send_names(channel)
            @client.send_names channel
            channel
        end

        def send_message(channel,message)
            @client.msg_channel channel, message
            channel
        end
        
        def send(message)
            @client.send message
            message
        end

        def run
            while true
                begin
                    method,args = :unknown,''
                    @eventlock.synchronize {
                        @eventqueue.wait(@eventlock) if @events.empty?
                        method,args = @events.shift
                    }
                    self[method].each {|block| block[*args] }
                rescue SystemExit => e
                    exit 0
                rescue Exception => e
                    carp e
                end
            end
        end
        def join(channel)
            @client.send_join channel
            @channels[channel] = Time.now
            channel
        end
        def part(channel)
            if @channels.delete(channel)
                @client.send_part channel
                channel
            else
                'not member'
            end
        end
        def nick
            return @nick
        end

        def names(channel)
            return @client.names(channel)
        end 
        
    end

    class PrintActor < HiveActor
        def initialize(client)
            super(client)
            on(:connect) {|server,port,nick,pass|
                client.send_join '#hive'
            }
            on(:numeric) {|server,numeric,msg,detail|
                #puts "-:#{numeric}"
            }
            on(:join) {|nick,channel|
                #puts "#{nick} join-:#{channel}"
                #client.msg_channel '#markee', "heee"
            }
            on(:part) {|nick,channel,msg|
                #puts "#{nick} part-:#{channel}"
            }
            on(:quit) {|nick,msg|
                #puts "#{nick} quit-:#{channel}"
            }
        end
    end
    class TestActor < HiveActor
        def initialize(client)
            super(client)
            on(:connect) {|server,port,nick,pass|
                client.send_join '#hive'
            }
            on(:numeric) {|server,numeric,msg,detail|
                puts "-:#{numeric}"
            }
            on(:join) {|nick,channel|
                puts "#{nick} join-:#{channel}"
            }
            on(:part) {|nick,channel,msg|
                puts "#{nick} part-:#{channel}"
            }
            on(:quit) {|nick,msg|
                puts "#{nick} quit-:#{nick}:#{msg}"
            }
            on(:privmsg) {|nick,channel,msg|
                case msg
                when /^ *!who +([^ ]+) *$/
                    names = names($1)
                    send_message channel, "names: #{names.join(',')}"
                end
            }
        end
    end
end
