require 'netutils'
require 'ircreplies'
require 'actors'

module HiveConnector
#=====================================================
    class ProxyConnector
        attr_reader :server, :nick
        attr_writer :actor
        def initialize(nick, pass, server, actor)
            @server = 'service'
            @nick = nick
            @pass = pass
            @actor = actor.new(self)
            @ircserver = server
        end

        #=====================================================
        def invoke(method, *args)
            @actor[method].each{|c| c[*args]}
        end
        
        #called during connection.
        def connect
            @actor[:connect].each{|c| c[ @server, @port, @nick, @pass]}
        end

        def ping(arg)
            @actor[:ping].each{|c| c[arg]}
        end

        def privmsg(nick, channel, msg)
            @actor[:privmsg].each{|c| c[nick, channel, msg]}
        end

        def notice(nick, channel, msg)
            @actor[:notice].each{|c| c[nick, channel, msg]}
        end

        def join(nick, channel)
            @actor[:join].each{|c| c[nick, channel]}
        end

        def part(nick, channel, msg)
            @actor[:part].each{|c| c[nick, channel, msg]}
        end

        def quit(nick, msg)
            @actor[:quit].each{|c| c[nick, msg]}
        end

        def numeric(server,numeric,msg, detail)
            @actor[:numeric].each{|c| c[server,numeric,msg,detail]}
        end

        def unknown(arg)
            @actor[:unknown].each{|c| c[arg]}
        end
       
        #=====================================================
        def send_pong(arg)
            @ircserver.invoke :pong,arg
        end

        def send_pass(arg)
            @ircserver.invoke :pass,arg
        end
        def send_nick(arg)
            @ircserver.invoke :nick,arg
        end
        def send_user(user,mode,unused,real)
            @ircserver.invoke :user, user, mode, unused, real
        end
        def send_names(arg)
            @ircserver.invoke :names,arg
        end
        def send_join(arg)
            @ircserver.invoke :join,arg
        end
        def send_part(arg)
            @ircserver.invoke :part,arg
        end
        def msg_channel(channel, data)
            @ircserver.invoke :privmsg,channel, data
        end
        #=====================================================
        def names(channel)
            return @ircserver.names(channel)
        end

        def msg_user(user,data)
            msg_channel(user, data)
        end
    end
end
