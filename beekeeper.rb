require 'ircclient'
module IrcClient
    class BeeStore
        def initialize
            @watches = {}
        end
        def [](bee)
            return @watches[bee]
        end
        def []=(bee,value)
            if @watches[bee]
                @watches[bee] = value
            end
        end
        def <<(bee)
            @watches[bee] = 'out'
        end
        def delete(bee)
            @watches.delete(bee)
        end
        def keys
            @watches.keys
        end
    end
    class HiveStore
        def initialize
            @watches = {$config['hive'] => BeeStore.new}
        end
        def [](channel)
            if @watches[channel]
                return @watches[channel]
            else
                return {}
            end
        end
        def []=(channel,bee)
            unless @watches[channel]
                @watches[channel] = BeeStore.new 
            end
            @watches[channel]<< bee
        end
        def <<(channel)
            @watches[channel] = BeeStore.new
        end
        def delete(channel)
            @watches.delete(channel)
        end
        def channels
            @watches.keys
        end
    end

    class BeeKeeper < IrcClient::IrcActor
        def initialize(client)
            begin
            super(client)
            @file = 'hive.yaml'
            @hive = restore() || HiveStore.new
            @hive.channels.each{|c|
                c.strip!
                @hive[c].keys.each {|bee|
                    @hive[c][bee] = 'out'
                }
            }
            on(:connect) {|server,port,nick,pass|
                client.send_join '#hive'
                @hive.channels.each{|c|
                    client.send_join c
                }
            }
            on(:privmsg) {|nick,channel,msg|
                begin
                if msg =~ /^([^\[]+)\[(.*)\] *$/
                    msg = "#{$1} #{$2}"
                end
                if channel =~ /^[^#]+/
                    msg = '!$keeper:'+ msg if msg !~ /^!\$keeper/
                    channel = nick #the return message should go to user.
                end
                case msg
                when /^!\$keeper:join +(.+)$/
                    $1.split(/,/).each {|c|
                        @hive << channel
                        client.send_join c.strip
                    }
                    persist
                when /^!\$keeper:part +(.+)$/
                    $1.split(/,/).each {|c|
                        @hive.delete(c)
                        client.send_part c.strip
                    }
                    persist
                when /^!\$keeper:part *$/
                    @hive.delete(channel)
                    client.send_part channel
                    persist
                when /^!\$keeper:reinit *$/
                    @hive = HiveStore.new 
                    persist
                when /^!\$keeper:add +([^ ]+) *$/
                    $1.split(/,/).each {|bee|
                        @hive[channel] = bee.strip
                    }
                    persist
                    hive = names(channel)
                    hive.each{|bee|
                        @hive[channel][bee.strip] = 'in'
                    }
                    send_message channel, "hive: #{@hive[channel].keys.join(',')}"
                when /^!\$keeper:status *$/
                    @hive[channel].keys.each {|bee|
                        send_message channel, "#{bee}: #{@hive[channel][bee]}"
                    }
                when /^!\$keeper:status +(.+)$/
                    channels = $1.strip
                    if channels =~ /\*/
                        @hive.channels.each{|c|
                            c.strip!
                            @hive[c].keys.each {|bee|
                                send_message channel, "#{c}:#{bee}: #{@hive[c][bee]}"
                            }
                        }
                    else
                        channels.split(/,/).each{|c|
                            c.strip!
                            @hive[c].keys.each {|bee|
                                send_message channel, "#{c}:#{bee}: #{@hive[c][bee]}"
                            }
                        }
                    end
                when /^!\$keeper:snapshot *$/
                    snapshot(channel)
                    persist
                when /^!\$keeper:snapshot +(.+)$/
                    args = $1
                    if args =~ /\*/
                        @hive.channels.each{|c|
                            snapshot(c)
                        }
                    else
                        args.split(/,/).each{|c|
                            snapshot(c)
                        }
                    end
                    persist
                when /^!\$keeper:update *$/
                    update(channel)
                    persist
                when /^!\$keeper:update +(.+)$/
                    args = $1
                    if args =~ /\*/
                        @hive.channels.each{|c|
                            update(c)
                        }
                    else
                        args.split(/,/).each{|c|
                            update(c)
                        }
                    end
                    persist
                when /^!\$keeper:remove +([^ ]+) *$/
                    args = $1
                    if args =~ /\*/
                        @hive.delete(channel)
                    else
                        args.split(/,/).each {|bee|
                            @hive[channel].delete(bee.strip)
                        }
                    end
                    persist
                    send_message channel, "hive: #{@hive[channel].keys.join(',')}"
                when /^!\$keeper:ensure +(.+)$/
                    channels = $1.strip
                    if channels =~ /\*/
                        ensure_channels(@hive.channels)
                    else
                        ensure_channels(channels.split(/,/))
                    end
                when /^!\$keeper:ensure *$/
                    ensure_clients(channel)
                end
                rescue Exception => e
                    send_message channel, "error(keeper):" + e.message
                    puts e.message
                    puts e.backtrace
                end
            }
            on(:join) {|nick,channel|
                @hive[channel][nick.strip] = 'in'
            }
            on(:part) {|nick,channel,msg|
                @hive[channel][nick.strip] = 'out'
            }
            on(:quit) {|nick,msg|
                @hive.channels.each{|channel|
                    @hive[channel][nick.strip] = 'out'
                }
            }
            rescue Exception => e
                puts e.message
                puts e.backtrace.join("\n")
            end
        end

        def snapshot(c)
            return if c !~ /^#/
            @hive << c
            update(c)
        end

        def update(c)
            return if c !~ /^#/
            hive = names(c)
            hive.each{|bee|
                next if bee.nil? || bee.strip !~ /^_/
                @hive[c] = bee.strip
                @hive[c][bee.strip] = 'in'
            }
        end

        def ensure_channels(names)
            names.each{|c| ensure_clients(c.strip)}
        end

        def ensure_clients(c)
            current = names(c)
            @hive[c].keys.each {|bee|
                next if bee.nil? || bee !~ /^_/
                if @hive[c][bee] =~ /out/
                    send_message bee, "!do $me:join[#{c}]"
                end
            }
            current.each {|bee|
                next if bee.nil? || bee !~ /^_/
                if @hive[c][bee].nil?
                    send_message bee, "!do $me:part[#{c}]"
                end
            }
        end

        def persist
            File.open(@file,"w") {|f| f.puts @hive.to_yaml }
        end
        def restore
            (File.open(@file){|y| YAML::load(y)} if FileTest.exists?(@file)) || nil
        end
    end
end
