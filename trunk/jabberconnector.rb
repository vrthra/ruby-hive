require 'xmpp4r'
require 'xmpp4r/client'
require 'xmpp4r/muc/helper/simplemucclient'
require 'actors.rb'
require 'netutils.rb'
#Jabber::debug = true

module HiveConnector
    class JabberConnector
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
        end

        def run
            connect()
            @eventloop = Thread.new { @actor.run }
            while true
                sleep 1
                @jabber_cl.process
            end
        end

        def getroom(room)
            return room + '@conference.' + @server + '/' + @jabber[:nick]
        end

        def getmuc(room)
            if @rooms[room].nil?
                @rooms[room] = Jabber::MUC::SimpleMUCClient.new(@jabber_cl)
            end
            return @rooms[room]
        end

        def join_room_pvt(room)
            time_now = Time.now
            if @rooms[room].nil?
                muc = getmuc(room)
                muc.on_join {|time, nick|
                    @actor.push :join, nick.to_s, '#' + room.to_s if (time.nil? || time > time_now )
                }
                muc.on_leave {|time, nick|
                    @actor.push :part, nick.to_s, '#' + room.to_s if (time.nil? || time > time_now )
                }
                muc.on_message {|time,nick, text|
                    @actor.push :privmsg, nick, '#' + room, text if (time.nil? || time > time_now )
                }
                muc.on_private_message {|time,nick, text|
                    @actor.push :privmsg, nick.to_s, nick.to_s, text if (time.nil? || time > time_now )
                }
                muc.on_room_message {|time, text|
                    #@actor.push :notice, '#-', text if !(time < time_now)
                }
                muc.join(getroom(room))
            end
        end
        
        def part_room_pvt(room)
            muc = getmuc(room)
            muc.exit if muc
            @rooms.delete(room)
        end

        def connect()
            begin
                @jabber_resource = 'Hive'
                #allow socket to be handed over from elsewhere.
                @jabber_jid = @jabber_jid || Jabber::JID::new(@nick + "@" + @server + '/' + @jabber_resource)
                puts "Connecting to #{@nick}@#{@server}/#{@resource} pass #{@pass}"
                #we want a non threaded version.
                @jabber_cl = Jabber::Client::new(@jabber_jid, false)
                @jabber_cl.connect(@server, @port)
                @jabber_cl.add_message_callback {|m|
                    @actor.push :privmsg, m.from.node, m.from.node, m.body
                }
                @rooms = {}
                @jabber = {}
                @actor[:connect].each{|c| c[ @server, @port, @nick, @pass]}
                puts 'connected.'
            rescue Exception => e
                puts e.message
                puts e.backtrace
                raise "Cannot connect #{@server}"
            end
        end

        #=========================================================== 

        #will be invoked from a thread different from that of the
        #primary IrcConnector thread.
        def names(channel)
            return @rooms[channel.sub(/^#/,'')].keys
        end

        #=====================================================
        #=====================================================
        def send_pong(arg)
            raise 'pong not impl'
        end
        def send_pass(pass)
            @jabber_cl.auth(pass)
            @jabber_cl.send(Jabber::Presence::new)
        end
        def send_nick(nick)
            #jabber uses nicks for rooms.
            @jabber[:nick] = nick
        end
        def send_user(user,mode,unused,real)
            @jabber[:user] = [user, mode, unused, real]
        end
        def send_names(channel)
            raise 'send_names not impl use names instead.'
        end
        def send(msg)
            raise 'Send Not exposed use specific methods instead.'
        end
        #=====================================================
        def send_join(channel)
            join_room_pvt channel.sub(/^#/,'')
        end
        def send_part(channel)
            part_room_pvt channel.sub(/^#/,'')
        end

        def msg_user(user,data)
            raise 'Msg user not exposed'
        end

        def msg_channel(channel, data)
            muc = getmuc(channel.sub(/^#/,''))
            muc.say(data.strip)
        end

        def notice_channel(channel, data)
            msg = Jabber::Message::new(getroom(channel.sub(/^#/,'')), data)
            msg.set_type(:headline)
            muc = getmuc(channel.sub(/^#/,''))
            muc.send(data.strip)
        end

        #=====================================================
        def JabberConnector.start(opts={})
            server = 'hiveserver'
            nick = 'hivenick'
            port = opts[:port] || 5222
            pass = 'hivepass'
            client = JabberConnector.new(server, port , nick, pass)
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
                puts e.message
                carp e
            end
        end
    end
    CONNECTOR = JabberConnector
end
